#ifndef _TYPE_H_
#define _TYPE_H_


#include <cstdio>
#include "baseAST.h"
#include "../ifa/num.h"

/*
  Things which must be changed if instance variables are added
  to Types:

  1. add variable to class and constructor
  2. copy variable in copyInner

*/

class Symbol;
class EnumSymbol;
class VarSymbol;
class TypeSymbol;
class ArgSymbol;
class FnSymbol;
class ConceptSymbol;
class Expr;
class DefExpr;
class CallExpr;
class CondStmt;
class BlockStmt;
class ClassType;


class Type : public BaseAST {
 public:
  Vec<Type*> dispatchParents; // dispatch hierarchy
  Vec<Type*> dispatchChildren; // dispatch hierarchy
  Type* scalarPromotionType;

  TypeSymbol* symbol;
  Symbol* defaultValue;
  FnSymbol* defaultConstructor;
  FnSymbol* defaultTypeConstructor;
  FnSymbol* destructor;
  Vec<FnSymbol*> methods;
  bool hasGenericDefaults; // all generic fields have defaults
  Type *instantiatedFrom;
  SymbolMap substitutions;
  ClassType* refType;  // pointer to references for non-reference types

  Type(AstTag astTag, Symbol* init_defaultVal);
  virtual ~Type();
  virtual Type* copy(SymbolMap* map = NULL, bool internal = false) = 0;
  virtual Type* copyInner(SymbolMap* map) = 0;
  virtual void replaceChild(BaseAST* old_ast, BaseAST* new_ast) = 0;

  virtual void verify(); 
  virtual bool inTree();
  virtual Type* typeInfo(void);

  void addSymbol(TypeSymbol* newSymbol);

  virtual void codegen(FILE* outfile);
  virtual void codegenDef(FILE* outfile);
  virtual void codegenPrototype(FILE* outfile);
  virtual int codegenStructure(FILE* outfile, const char* baseoffset);

  virtual Symbol* getField(const char* name, bool fatal=true);
};

#define forv_Type(_p, _v) forv_Vec(Type, _p, _v)

class EnumType : public Type {
 public:
  AList constants; // EnumSymbols
  PrimitiveType* integerType; // what integer type contains all of this enum values?
                              // if this is NULL it will just be recomputed when needed.

  EnumType();
  ~EnumType();
  void verify(); 
  DECLARE_COPY(EnumType);
  void replaceChild(BaseAST* old_ast, BaseAST* new_ast);

  void codegenDef(FILE* outfile);
  int codegenStructure(FILE* outfile, const char* baseoffset);

  // computes integerType and does the next=last+1 assignments.
  // This will only really work after the function resolution.
  void sizeAndNormalize();
  PrimitiveType* getIntegerType();
};


enum ClassTag {
  CLASS_CLASS,
  CLASS_RECORD,
  CLASS_UNION
};

class ClassType : public Type {
 public:
  ClassTag classTag;
  AList fields;
  AList inherits; // used from parsing, sets dispatchParents
  Symbol* outer;  // pointer to an outer class if this is an inner class

  ClassType(ClassTag initClassTag);
  ~ClassType();
  void verify(); 
  DECLARE_COPY(ClassType);
  void replaceChild(BaseAST* old_ast, BaseAST* new_ast);
  void addDeclarations(Expr* expr, bool tail = true);

  void codegenDef(FILE* outfile);
  void codegenPrototype(FILE* outfile);
  int codegenStructure(FILE* outfile, const char* baseoffset);
  int codegenFieldStructure(FILE* outfile, bool nested, const char* baseoffset);

  Symbol* getField(const char* name, bool fatal=true);
  Symbol* getField(int i);
};


class PrimitiveType : public Type {
 public:
  PrimitiveType* volType; 
  PrimitiveType* nonvolType;
  bool isInternalType;
  PrimitiveType(Symbol *init_defaultVal = NULL, bool internalType=false);
  void verify(); 
  DECLARE_COPY(PrimitiveType);
  void replaceChild(BaseAST* old_ast, BaseAST* new_ast);
  int codegenStructure(FILE* outfile, const char* baseoffset);
};


#ifndef TYPE_EXTERN
#define TYPE_EXTERN extern
#endif

// internal types
TYPE_EXTERN Type* dtAny;
TYPE_EXTERN Type* dtIteratorRecord;
TYPE_EXTERN Type* dtIteratorClass;
TYPE_EXTERN Type* dtIntegral;
TYPE_EXTERN Type* dtAnyComplex;
TYPE_EXTERN Type* dtNumeric;
TYPE_EXTERN Type* dtAnyEnumerated;
TYPE_EXTERN PrimitiveType* dtNil;
TYPE_EXTERN PrimitiveType* dtUnknown;
TYPE_EXTERN PrimitiveType* dtVoid;
TYPE_EXTERN PrimitiveType* dtValue;
TYPE_EXTERN PrimitiveType* dtMethodToken;
TYPE_EXTERN PrimitiveType* dtTypeDefaultToken;
TYPE_EXTERN PrimitiveType* dtModuleToken;

// primitive types
TYPE_EXTERN PrimitiveType* dtBool;
TYPE_EXTERN PrimitiveType* dtBools[BOOL_SIZE_NUM];
TYPE_EXTERN PrimitiveType* dtInt[INT_SIZE_NUM];
TYPE_EXTERN PrimitiveType* dtUInt[INT_SIZE_NUM];
TYPE_EXTERN PrimitiveType* dtReal[FLOAT_SIZE_NUM];
TYPE_EXTERN PrimitiveType* dtImag[FLOAT_SIZE_NUM];
TYPE_EXTERN PrimitiveType* dtComplex[COMPLEX_SIZE_NUM];
TYPE_EXTERN PrimitiveType* dtString;
TYPE_EXTERN PrimitiveType* dtSymbol;
TYPE_EXTERN PrimitiveType* dtFile; 
TYPE_EXTERN PrimitiveType* dtOpaque;
TYPE_EXTERN PrimitiveType* dtTimer; 
TYPE_EXTERN PrimitiveType* dtTaskID;
TYPE_EXTERN PrimitiveType* dtSyncVarAuxFields;
TYPE_EXTERN PrimitiveType* dtSingleVarAuxFields;
TYPE_EXTERN PrimitiveType* dtTaskList;

// a fairly special wide type
extern ClassType* wideStringType;

// standard module types
TYPE_EXTERN ClassType* dtArray;
TYPE_EXTERN ClassType* dtReader;
TYPE_EXTERN ClassType* dtWriter;
TYPE_EXTERN ClassType* dtBaseArr;
TYPE_EXTERN ClassType* dtBaseDom;
TYPE_EXTERN ClassType* dtDist;
TYPE_EXTERN ClassType* dtTuple;
TYPE_EXTERN ClassType* dtLocale;

// base object type (for all classes)
TYPE_EXTERN Type* dtObject;

TYPE_EXTERN Map<Type*,Type*> wideClassMap; // class -> wide class
TYPE_EXTERN Map<Type*,Type*> wideRefMap;   // reference -> wide reference

void initChplProgram(void);
void initPrimitiveTypes(void);
void initTheProgram(void);
void initCompilerGlobals(void);

bool is_bool_type(Type*);
bool is_int_type(Type*);
bool is_uint_type(Type*);
bool is_real_type(Type*);
bool is_imag_type(Type*);
bool is_complex_type(Type*);
bool is_enum_type(Type*);
#define is_arithmetic_type(t) (is_int_type(t) || is_uint_type(t) || is_real_type(t) || is_imag_type(t) || is_complex_type(t))
int  get_width(Type*);
bool isClass(Type* t);
bool isRecord(Type* t);
bool isUnion(Type* t);

bool isReferenceType(Type* t);

bool isRefCountedType(Type* t);
bool isRecordWrappedType(Type* t);
bool isSyncType(Type* t);

bool isDistClass(Type* type);
bool isDomainClass(Type* type);
bool isArrayClass(Type* type);

void registerTypeToStructurallyCodegen(TypeSymbol* type);
void genTypeStructureIndex(FILE *outfile, TypeSymbol* typesym);
void codegenTypeStructures(FILE* hdrfile);
void codegenTypeStructureInclude(FILE* outfile);

#endif
