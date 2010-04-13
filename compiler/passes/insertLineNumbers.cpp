#include "astutil.h"
#include "expr.h"
#include "passes.h"
#include "stmt.h"
#include "symbol.h"

//
// insertLineNumbers() inserts line numbers and filenames into
// functions and calls so that runtime errors show line number and
// filename information.  The line numbers and filenames always point
// to user code, i.e., code that is not in a standard module or in a
// compiler-generated function.  To this effect, functions that are in
// a standard module or are compiler-generated are passed a line
// number and a filename.
//

//
// The queue keeps track of the functions to which line number and
// filename arguments have been added so that calls to these functions
// can be updated with new actual arguments.
//
static Vec<FnSymbol*> queue;

static Map<FnSymbol*,ArgSymbol*> linenoMap; // fn to line number argument
static Map<FnSymbol*,ArgSymbol*> filenameMap; // fn to filename argument

static ArgSymbol* newLine(FnSymbol* fn) {
  ArgSymbol* line = new ArgSymbol(INTENT_BLANK, "_ln", dtInt[INT_SIZE_32]);
  fn->insertFormalAtTail(line);
  linenoMap.put(fn, line);
  if (Vec<FnSymbol*>* rootFns = virtualRootsMap.get(fn)) {
    forv_Vec(FnSymbol, rootFn, *rootFns)
      if (!linenoMap.get(rootFn))
        newLine(rootFn);
  } else if (Vec<FnSymbol*>* childrenFns = virtualChildrenMap.get(fn)) {
    forv_Vec(FnSymbol, childrenFn, *childrenFns)
      if (!linenoMap.get(childrenFn))
        newLine(childrenFn);
  }
  return line;
}

static ArgSymbol* newFile(FnSymbol* fn) {
  ArgSymbol* file = new ArgSymbol(INTENT_BLANK, "_fn", dtString);
  fn->insertFormalAtTail(file);
  filenameMap.put(fn, file);
  queue.add(fn);
  if (Vec<FnSymbol*>* rootFns = virtualRootsMap.get(fn)) {
    forv_Vec(FnSymbol, rootFn, *rootFns)
      if (!filenameMap.get(rootFn))
        newFile(rootFn);
  } else if (Vec<FnSymbol*>* childrenFns = virtualChildrenMap.get(fn)) {
    forv_Vec(FnSymbol, childrenFn, *childrenFns)
      if (!filenameMap.get(childrenFn))
        newFile(childrenFn);
  }
  return file;
}

//
// insert a line number and filename actual into a call; add line
// number and filename formal arguments to the function in which this
// call lives if necessary, and add it to the queue.
//
static void
insertLineNumber(CallExpr* call) {
  FnSymbol* fn = call->getFunction();
  ModuleSymbol* mod = fn->getModule();
  ArgSymbol* file = filenameMap.get(fn);
  ArgSymbol* line = linenoMap.get(fn);

  if (call->isPrimitive(PRIM_GET_USER_FILE) || 
      call->isPrimitive(PRIM_GET_USER_LINE)) {
    
    // add both arguments or none
    if (!file) { 
      line = newLine(fn);
      file = newFile(fn);
    }
    
    // 
    if (call->isPrimitive(PRIM_GET_USER_FILE)) {
      call->replace(new SymExpr(file));
    } else if (call->isPrimitive(PRIM_GET_USER_LINE)) {
      call->replace(new SymExpr(line));
    }
  } else if (!strcmp(fn->name, "chpl__heapAllocateGlobals") ||
             !strcmp(fn->name, "chpl__initModuleGuards") ||
             !strcmp(fn->name, "chpl_main") ||
             ((mod->modTag == MOD_USER || mod->modTag == MOD_MAIN) && 
              !fn->hasFlag(FLAG_TEMP) && !fn->hasFlag(FLAG_INLINE)) ||
             (developer == true && strcmp(fn->name, "halt"))) {
    // call is in user code; insert AST line number and filename
    // or developer flag is on and the call is not the halt() call
    if (call->isResolved() &&
        call->isResolved()->hasFlag(FLAG_COMMAND_LINE_SETTING)) {
      call->insertAtTail(new_IntSymbol(0));
      FnSymbol* fn = call->isResolved();
      INT_ASSERT(fn);
      INT_ASSERT(fn->substitutions.n);
      VarSymbol* var = toVarSymbol(fn->substitutions.v[0].value);
      INT_ASSERT(var);
      INT_ASSERT(var->immediate);
      INT_ASSERT(var->immediate->const_kind == CONST_KIND_STRING);
      call->insertAtTail(new_StringSymbol(astr("<command line setting of '",
                                               var->immediate->v_string,
                                               "'>")));
    } else {
      if (fCLineNumbers) {
        if (!gCLine) {
          gCLine = new VarSymbol("__LINE__", dtInt[INT_SIZE_32]);
          rootModule->block->insertAtTail(new DefExpr(gCLine));
          gCFile = new VarSymbol("__FILE__", dtString);
          rootModule->block->insertAtTail(new DefExpr(gCFile));
        }
        call->insertAtTail(gCLine);
        call->insertAtTail(gCFile);
      } else {
        call->insertAtTail(new_IntSymbol(call->lineno));
        call->insertAtTail(new_StringSymbol(call->getModule()->filename));
      }
    }
  } else if (file) {
    // call is in non-user code, but the function already has line
    // number and filename arguments
    call->insertAtTail(line);
    call->insertAtTail(file);
  } else {
    // call is in non-user code, and the function requires new line
    // number and filename arguments
    line = newLine(fn);
    file = newFile(fn);

    call->insertAtTail(line);
    call->insertAtTail(file);
  }
}


static bool isClassMethodCall(CallExpr* call) {
  FnSymbol* fn = call->isResolved();
  if (fn && fn->hasFlag(FLAG_METHOD) && fn->_this) {
    if (ClassType* ct = toClassType(fn->_this->typeInfo())) {
      if (fn->numFormals() > 0 &&
          fn->getFormal(1)->typeInfo() == fn->_this->typeInfo()) {
        if (isClass(ct) || ct->symbol->hasFlag(FLAG_WIDE_CLASS)) {
          return true;
        }
      }
    }
  }
  return false;
}


void insertLineNumbers() {
  compute_call_sites();

  // insert nil checks primitives in front of all member accesses
  if (!fNoNilChecks) {
    forv_Vec(CallExpr, call, gCallExprs) {
      if (call->isPrimitive(PRIM_GET_MEMBER) ||
          call->isPrimitive(PRIM_GET_MEMBER_VALUE) ||
          call->isPrimitive(PRIM_SET_MEMBER) ||
          call->isPrimitive(PRIM_GETCID) ||
          call->isPrimitive(PRIM_TESTCID) ||
          isClassMethodCall(call)) {
        Expr* stmt = call->getStmtExpr();
        SET_LINENO(stmt);
        ClassType* ct = toClassType(call->get(1)->typeInfo());
        if (ct && (isClass(ct) || ct->symbol->hasFlag(FLAG_WIDE_CLASS))) {
          if (!call->getFunction()->hasFlag(FLAG_GPU_ON)) // disable in GPU
            stmt->insertBefore(
              new CallExpr(PRIM_CHECK_NIL, call->get(1)->copy()));
        }
      }
    }
  }

  // loop over all primitives that require a line number and filename
  // and pass them an actual line number and filename
  forv_Vec(CallExpr, call, gCallExprs) {
    if (call->primitive && call->primitive->passLineno) {
      insertLineNumber(call);
    }
  }

  // loop over all functions in the queue and all calls to these
  // functions, and pass the calls an actual line number and filename
  forv_Vec(FnSymbol, fn, queue) {
    forv_Vec(CallExpr, call, *fn->calledBy) {
      insertLineNumber(call);
    }
  }

  // pass line number and filename arguments to functions that are
  // forked via the argument class
  forv_Vec(FnSymbol, fn, gFnSymbols) {
    // If we added arguments to a the the following wrapper functions,
    //  the number of formals should be now be (precisely two) greater
    //  than the expected number.  Both block types below expect an
    //  argument bundle, and the on-block expects an additional argument
    //  that is the locale on which it should be executed.
    if ((fn->numFormals() > 2 && fn->hasFlag(FLAG_ON_BLOCK)) ||
        (fn->numFormals() > 1 && fn->hasFlag(FLAG_COBEGIN_OR_COFORALL_BLOCK)) ||
        (fn->numFormals() > 1 && fn->hasFlag(FLAG_BEGIN_BLOCK))) {

      DefExpr* filenameFormal = toDefExpr(fn->formals.tail);
      filenameFormal->remove();
      DefExpr* linenoFormal = toDefExpr(fn->formals.tail);
      linenoFormal->remove();
      DefExpr* argClassFormal = toDefExpr(fn->formals.tail);

      forv_Vec(CallExpr, call, *fn->calledBy) {
        Expr* filename = call->argList.tail->remove();
        Expr* lineno = call->argList.tail->remove();
        Expr* argClass = call->argList.tail;
        ClassType* ct = toClassType(argClass->typeInfo());
        VarSymbol* linenoField = newTemp("_ln", lineno->typeInfo());
        ct->fields.insertAtTail(new DefExpr(linenoField));
        VarSymbol* filenameField = newTemp("_fn", filename->typeInfo());
        ct->fields.insertAtTail(new DefExpr(filenameField));
        call->insertBefore(new CallExpr(PRIM_SET_MEMBER, argClass->copy(), linenoField, lineno));
        call->insertBefore(new CallExpr(PRIM_SET_MEMBER, argClass->copy(), filenameField, filename));
        VarSymbol* filenameLocal = newTemp("_fn", filename->typeInfo());
        VarSymbol* linenoLocal = newTemp("_ln", lineno->typeInfo());
        fn->insertAtHead(new CallExpr(PRIM_MOVE, filenameLocal, new CallExpr(PRIM_GET_MEMBER_VALUE, argClassFormal->sym, filenameField)));
        fn->insertAtHead(new DefExpr(filenameLocal));
        fn->insertAtHead(new CallExpr(PRIM_MOVE, linenoLocal, new CallExpr(PRIM_GET_MEMBER_VALUE, argClassFormal->sym, linenoField)));
        fn->insertAtHead(new DefExpr(linenoLocal));
        SymbolMap update;
        update.put(filenameFormal->sym, filenameLocal);
        update.put(linenoFormal->sym, linenoLocal);
        update_symbols(fn->body, &update);
      }
    }
  }
}
