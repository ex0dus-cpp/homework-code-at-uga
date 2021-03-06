/* 
 * token declarations
 */

%{

#include <stdio.h>
#include <errno.h>
#include <vector>
#include <iostream>
#include "string.h"
#include "Ast.h"
#include "y.tab.h"

#include "SymbolTable.h"

using namespace std;

#define YYERROR_VERBOSE

void free(void *ptr);
void yyerror( const char *msg );
void error( const char *msg );
int yylex( void );
void error_semi();
void clear_error();

extern int yylineno;
extern int yyin;
extern char* yytext;
extern int yychar;
int yyerrstatus;
extern int yydebug;
extern Declaration *declTree;

MethodDeclaration *methodDecl = NULL;
ClassDeclaration *classDecl = NULL;
SymbolTable* table = new SymbolTable();

ParameterEntry* parameter_e = NULL;
MethodEntry* method_e = NULL;
VariableEntry* variable_e = NULL;
ClassEntry* class_e = NULL;
FieldEntry* field_e = NULL;
char current_class_name[1024];
%}

%union {
  int	          	 ival;    //e.g., type representation
  char           	*sval;    //e.g., lexemes (idents, literals)
  Entry*          	 eval;    //symbol table entry
  Statement      	*tval;    //a Statement object reference
  BlockStatement 	*bval;    //a BlockStatement reference
  Expression     	*xval;    //an Expression reference
  MethodCallExpression  *mval;    //a MethodCallExpression reference
  Declaration           *dval;    //a Declaration reference
  std::vector<int>    	*vival;     //a reference to a vector of type representations
  std::vector<Expression *>  *aval;  //a reference to a vector of Expression references
                                //        (actual arguments of a method call)
  std::vector<Declaration *>  *vdval; //  a reference to a vector of Declaration references
                                //        (a list of local declarations
                                //         or formal paramater declarations)
}

%token IDENT
%token FLOATLITERAL
%token INTLITERAL
%token STRING
%token ICOMMENT
%token LPAR
%token RPAR
%token SEMI
%token DOT
%token LBRACE
%token RBRACE
%token EQUAL
%token DQUOTE
%token LESS
%token GREATER
%token LBRACKET
%token RBRACKET
%token MINUS
%token PLUS
%token MUL
%token DIVIDE
%token BCOMMENTSTART
%token BCOMMENTEND
%token ERROR
%token KEYWORD
%token ASSIGN
%token GREATEREQUAL
%token LESSEQUAL
%token INCREMENT
%token DECREMENT
%token COMMA
%token NOTEQUAL
%token RETURN
%token IF
%token ELSE
%token FOR
%token NEW
%token NULL_
%token INT
%token FLOAT
%token VOID
%token PUBLIC
%token STATIC
%token WHILE
%token CLASS

%type <sval>   INTLITERAL
%type <sval>   FLOATLITERAL
%type <sval>   STRING
%type <sval>   NULL_
%type <xval>   literal
%type <ival>   type
%type <xval>   primary_expression
%type <xval>   unary_expression
%type <xval>   multiplicative_expression
%type <xval>   additive_expression
%type <xval>   relational_expression
%type <xval>   expression
%type <tval>   statement
%type <tval>   return_statement
%type <tval>   method_body
%type <xval>   method_invocation
%type <bval>   statement_list
%type <bval>   method_statement_list
%type <aval>   argument_list
%type <dval>   local_decl
%type <vdval>  local_decl_list
%type <dval>   formal_param
%type <vdval>  formal_param_list
%type <sval>   IDENT
%type <xval>   class_decl
%type <dval>   member_decl
%type <vdval>  member_decl_list
%type <dval>   method_decl
%type <dval>   field_decl
%type <tval>   opt_else

%%

tiny_java_program: class_decl
                 {
                    declTree = classDecl;
                 }
                 ;

class_decl: class_decl PUBLIC CLASS IDENT
          {
            snprintf(current_class_name, 1024, $4);
            classDecl = new ClassDeclaration( yylineno, $4 );
          }
          LBRACE member_decl_list RBRACE
          | empty
          ;

member_decl_list: member_decl
                {
                    $$ = new vector<Declaration *>();
                    $$->push_back($1);
                }
                |
                member_decl member_decl_list
                {
                    $$ = $2;
                    $$->push_back($1);
                }
                ;

member_decl: field_decl
           {
            $$ = $1;
           }
           |
           method_decl
           {
            $$ = $1;
           }
           ;

field_decl: STATIC INT IDENT ASSIGN literal SEMI
          {
            $$ = new FieldDeclaration(yylineno, $3, AstNode::TINT, (LiteralExpression*) $5);
            classDecl->addMember($$);
          }
          |
          STATIC FLOAT IDENT ASSIGN literal SEMI
          {
            $$ = new FieldDeclaration(yylineno, $3, AstNode::TFLOAT, (LiteralExpression*) $5);
            classDecl->addMember($$);
          }
          |
          STATIC type LBRACKET RBRACKET IDENT ASSIGN literal SEMI
          {
            if ($2 == AstNode::TINT){
                $$ = new FieldDeclaration(yylineno, $5, AstNode::TINTA, (LiteralExpression*) $7);
            }
            else if ($2 == AstNode::TFLOAT){
                $$ = new FieldDeclaration(yylineno, $5, AstNode::TFLOATA, (LiteralExpression*) $7);
            }
            else if ($2 == AstNode::TSTRING){
                $$ = new FieldDeclaration(yylineno, $5, AstNode::TSTRINGA, (LiteralExpression*) $7);
            }
            classDecl->addMember($$);
          }
          /*
          |
          STATIC INT IDENT ASSIGN literal SEMI
          {
	        classDecl->addMember( new FieldDeclaration( yylineno, $3, AstNode::TINT, $5 ) );
          }
          |
          STATIC FLOAT LBRACKET RBRACKET IDENT ASSIGN NEW type array_define_index SEMI
          |
          STATIC INT LBRACKET RBRACKET IDENT ASSIGN NEW type array_define_index SEMI
          |
          STATIC type LBRACKET RBRACKET IDENT ASSIGN NEW type array_define_index list_literal SEMI
          |
          STATIC type LBRACKET RBRACKET IDENT ASSIGN NEW type array_define_index list_literal err {
            error_semi();
          }
          */
          ;

method_decl:
           STATIC VOID IDENT LPAR
           {
              methodDecl = new MethodDeclaration( yylineno, $3, AstNode::TVOID );
              classDecl->addMember( methodDecl );


              //table->use_scope("class");
              //method_e = new MethodEntry($3, VOID);
              //table->install(method_e);
              //methodDecl->setEntry(method_e);
              //table->use_scope("method");
              //table->get_scope()->set_name($3);
           }
           formal_param_list RPAR
           {
            //table->use_scope("method");
            methodDecl->setParameters( $6 );
            //method_e->setParameters($6);
           }
           LBRACE method_body RBRACE
           |
           STATIC INT IDENT LPAR
           {
              methodDecl = new MethodDeclaration( yylineno, $3, AstNode::TINT );
              classDecl->addMember( methodDecl );

              //table->use_scope("class");
              //method_e = new MethodEntry($3, INT);
              //table->install(method_e);
              //methodDecl->setEntry(method_e);
              //table->use_scope("method");
              //table->get_scope()->set_name($3);
           }
           formal_param_list RPAR
           {
            methodDecl->setParameters( $6 );
            //method_e->setParameters($6);
           }
           LBRACE method_body RBRACE
           |
           STATIC FLOAT IDENT LPAR
           {
              methodDecl = new MethodDeclaration( yylineno, $3, AstNode::TFLOAT );
              classDecl->addMember( methodDecl );

              //table->use_scope("class");
              //method_e = new MethodEntry($3, FLOAT);
              //table->install(method_e);
              //methodDecl->setEntry(method_e);
              //table->use_scope("method");
              //table->get_scope()->set_name($3);
           }
           formal_param_list RPAR
           {
            methodDecl->setParameters( $6 );
            //method_e->setParameters($6);
           }
           LBRACE method_body RBRACE
           |
           STATIC VOID IDENT LPAR RPAR
           {
            methodDecl = new MethodDeclaration(yylineno, $3, AstNode::TVOID);
            classDecl->addMember(methodDecl);

            //table->use_scope("class");
            //method_e = new MethodEntry($3, VOID);
            //table->install(method_e);
            //methodDecl->setEntry(method_e);
            //table->use_scope("method");
            //table->get_scope()->set_name($3);
           }
           LBRACE method_body RBRACE
           |
           STATIC INT IDENT LPAR RPAR
           {
            methodDecl = new MethodDeclaration(yylineno, $3, AstNode::TINT);
            classDecl->addMember(methodDecl);

            //table->use_scope("class");
            //method_e = new MethodEntry($3, INT);
            //table->install(method_e);
            //methodDecl->setEntry(method_e);
            //table->use_scope("method");
            //table->get_scope()->set_name($3);
           }
           LBRACE method_body RBRACE
           |
           STATIC FLOAT IDENT LPAR RPAR
           {
            methodDecl = new MethodDeclaration(yylineno, $3, AstNode::TFLOAT);
            classDecl->addMember(methodDecl);

            //table->use_scope("class");
            //method_e = new MethodEntry($3, FLOAT);
            //table->install(method_e);
            //methodDecl->setEntry(method_e);
            //table->use_scope("method");
            //table->get_scope()->set_name($3);
           }
           LBRACE method_body RBRACE
           |
           PUBLIC STATIC VOID IDENT LPAR IDENT LBRACKET RBRACKET IDENT RPAR
           {
              ParameterDeclaration *pd = NULL;
              if( strcmp( $6, "String" ) == 0 ) {
                pd = new ParameterDeclaration( yylineno, $9, AstNode::TSTRINGA );
              }
              else {
                pd = new ParameterDeclaration( yylineno, $9, 0 );
              }
              vector<Declaration*> *pv = new vector<Declaration*>();
              pv->push_back( pd );
              methodDecl = new MethodDeclaration( yylineno, $4, AstNode::TVOID );
              methodDecl->setParameters( pv );
              methodDecl->setPublicMethod( true );
              classDecl->addMember(methodDecl);

              // SymbolTable
              //parameter_e = new ParameterEntry($9, INT);
              //method_e = new MethodEntry($4, VOID);
              //method_e->setParameters(pv);
              //table->use_scope("class");
              //table->install(method_e);
              //table->use_scope("method");
              //table->install(parameter_e);
              //table->get_scope()->set_name($4);

              //pd->setEntry(parameter_e);
              //methodDecl->setEntry(method_e);
              // end of symbol table
           }
           LBRACE method_body RBRACE
           ;

type: INT
    {
        $$ = AstNode::TINT;
    }
    |
    FLOAT
    {
        $$ = AstNode::TFLOAT;
    }
    ;


formal_param_list: formal_param
                 {
                 $$ = new vector<Declaration *>();
                 $$->push_back($1);
                 }
                 |
                 formal_param COMMA formal_param_list
                 {
                 $$ = $3;
                 $$->insert($$->begin(), $1);
                 }
                 ;

formal_param: type IDENT
            {
                $$ = new ParameterDeclaration(yylineno, $2, $1);
                //ParameterDeclaration* pd = new ParameterDeclaration(yylineno, $2, $1);
                //if($1 == 1){
                //    parameter_e = new ParameterEntry($2, INT);
                //}
                //else if ($1 == 2){
                //    parameter_e = new ParameterEntry($2, FLOAT);
                //}
                //else {
                //    throw string("Unkown type in formal_param");
                //}
                //table->install(parameter_e);
                //pd->setEntry(parameter_e);
                //$$ = pd;
            }
            |
            type LBRACKET RBRACKET IDENT
            {
                if($1 == AstNode::TINT){
                    $$ = new ParameterDeclaration(yylineno, $4, AstNode::TINTA);
                }
                else if($1 == AstNode::TFLOAT){
                    $$ = new ParameterDeclaration(yylineno, $4, AstNode::TFLOATA);
                }
                else if($1 == AstNode::TSTRING){
                    $$ = new ParameterDeclaration(yylineno, $4, AstNode::TSTRINGA);
                }
                //if($1 == 1){
                //    parameter_e = new ParameterEntry($4, INT);
                //}
                //else if ($1==2){
                //    parameter_e = new ParameterEntry($4, FLOAT);
                //}
                //else {
                //    throw string("Unkown type in formal_param");
                //}
                //table->install(parameter_e);
                //((ParameterDeclaration*)$$)->setEntry(parameter_e);
            }
            ;

method_body: local_decl_list method_statement_list
           {
            methodDecl->setVariables( $1 );
            methodDecl->setBody( $2 );
           }
           ;

local_decl_list: local_decl local_decl_list
               {
                $$ = $2;
                $$->push_back($1);
               }
               | empty
               {
	            $$ = new vector<Declaration*>();
               }
               ;

local_decl: type IDENT ASSIGN literal SEMI
          {
            VariableDeclaration* vd = new VariableDeclaration( yylineno, $2, $1, (LiteralExpression*) $4);
            $$ = vd;
            //if ($1 == 1){
            //    variable_e = new VariableEntry($2, INT, $4);
            //}
            //else if ($1 == 2){
            //    variable_e = new VariableEntry($2, FLOAT, $4);
            //}
            //else{
            //    throw string("Unkown type in local_decl");
            //}
            //table->install(variable_e);
            //vd->setEntry(variable_e);
          }
          |
          INT LBRACKET RBRACKET IDENT ASSIGN literal SEMI
          {
            $$ = new VariableDeclaration( yylineno, $4, AstNode::TINTA, (LiteralExpression*)$6);
            //if ($1 == 1){
            //    variable_e = new VariableEntry($4, INT, $6);
            //}
            //else if ($1 == 2){
            //    variable_e = new VariableEntry($4, FLOAT, $6);
            //}
            //table->install(variable_e);
            //vd->setEntry(variable_e);
          }
          ;

method_statement_list: statement method_statement_list
                     {
                        $$ = $2;
                        $$->prependStatement($1);
                     }
                     |
                     return_statement
                     {
                        $$ = new BlockStatement(yylineno);
                        $$->prependStatement($1);
                     }
                     ;

statement_list: statement statement_list
              {
                $$ = $2;
                $$->prependStatement($1);
              }
              | empty
              {
	            $$ = new BlockStatement( yylineno );
              }
              ;

opt_else: ELSE statement
        {
        $$ = new BlockStatement(yylineno);
        ((BlockStatement*)$$)->addStatement($2);
        }
        |
        empty
        {
        $$ = new EmptyStatement(yylineno);
        }
        ;


statement: IDENT ASSIGN expression SEMI
         {
	        $$ = new AssignStatement( yylineno, $1, $3 );
            //Entry* e = table->lookup($1);
            //((AssignStatement*)$$)->setEntry(e);
         }
         |
         IDENT LBRACKET primary_expression RBRACKET ASSIGN expression SEMI
         {
	        $$ = new AssignStatement( yylineno, $1, $3, $6);
            //Entry* e = table->lookup($1);
            //((AssignStatement*)$$)->setEntry(e);
         }
         |
         IF LPAR expression RPAR statement opt_else
         {
	        $$ = new IfStatement( yylineno, $3, $5, $6 );
         }
         |
         WHILE LPAR expression RPAR statement
         {
	        $$ = new WhileStatement( yylineno, $3, $5 );
         }
         |
         FOR LPAR IDENT ASSIGN expression SEMI expression SEMI expression RPAR statement
         {
            $$ = new ForStatement(yylineno, $3, $5, $7, $9, $11);
            //Entry* e = table->lookup($3);
            //((ForStatement*)$$)->setEntry(e);
         }
         |
         FOR LPAR IDENT LBRACKET expression RBRACKET ASSIGN expression SEMI expression SEMI expression RPAR statement
         {
            $$ = new ForStatement(yylineno, $3, $5, $8, $10, $12, $14);
            //Entry* e = table->lookup($3);
            //((ForStatement*)$$)->setEntry(e);
         }
         |
         method_invocation SEMI{
	        $$ = new MethodCallStatement( yylineno, $1 );
         }
         |
         LBRACE statement_list RBRACE
         {
	        $$ = $2;
         }
         |
         expression SEMI
         |
         SEMI
         {
	        $$ = new EmptyStatement( yylineno );
         }
         ;

return_statement: RETURN expression SEMI
                {
	                $$ = new ReturnStatement( yylineno, NULL, $2 );
                }
                |
                RETURN SEMI
                {
	                $$ = new ReturnStatement( yylineno, NULL, NULL );
                }
                ;

method_invocation: IDENT LPAR argument_list RPAR
                 {
	                $$ = new MethodCallExpression( yylineno, current_class_name, $1, $3 );
                    //Entry* e = table->lookup($1);
                    //((MethodCallExpression*)$$)->setEntry(e);
                 }
                 |
                 IDENT LPAR RPAR
                 {
	                $$ = new MethodCallExpression( yylineno, current_class_name, $1, (vector<Expression *> *) NULL );
                    //Entry* e = table->lookup($1);
                    //((MethodCallExpression*)$$)->setEntry(e);
                 }
                 |
                 IDENT DOT IDENT LPAR argument_list RPAR
                 {
	                $$ = new MethodCallExpression( yylineno, $1, $3, $5 );
                    //if(strcmp($1, "SimpleIO")==0){
                    //    Entry* e = table->get_scope("simpleio")->lookup($3);
                    //    ((MethodCallExpression*)$$)->setEntry(e);
                    //}
                    //else{
                    //    throw string("Class method invocation only supports SimpleIO class");
                    //}
                 }
                 |
                 IDENT DOT IDENT LPAR RPAR
                 {
	                $$ = new MethodCallExpression( yylineno, $1, $3, (vector<Expression *> *) NULL );
                    //if(strcmp($1, "SimpleIO")==0){
                    //    Entry* e = table->get_scope("simpleio")->lookup($3);
                    //    ((MethodCallExpression*)$$)->setEntry(e);
                    //}
                    //else{
                    //    throw string("Class method invocation only supports SimpleIO class");
                    //}
                 }
                 ;

argument_list: expression
             {
              $$ = new vector<Expression *>();
              $$->push_back( $1 );
             }
             |
             argument_list COMMA expression
             {
              $$ = $1;
              $$->push_back( $3 );
             }
             ;

expression: relational_expression
          {
            $$ = $1;
          }
          |
          relational_expression EQUAL relational_expression
          {
              $$ = new BinaryExpression( yylineno, AstNode::EQOP, $1, $3 );
          }
          |
          relational_expression NOTEQUAL relational_expression
          {
              $$ = new BinaryExpression( yylineno, AstNode::NEOP, $1, $3 );
          }
          ;

relational_expression: additive_expression
                     {
                     $$ = $1;
                     }
                     |
                     additive_expression GREATER additive_expression
                     {
                          $$ = new BinaryExpression( yylineno, AstNode::GTOP, $1, $3 );
                     }
                     |
                     additive_expression LESS additive_expression
                     {
                          $$ = new BinaryExpression( yylineno, AstNode::LTOP, $1, $3 );
                     }
                     |
                     additive_expression GREATEREQUAL additive_expression
                     {
                          $$ = new BinaryExpression( yylineno, AstNode::GEOP, $1, $3 );
                     }
                     |
                     additive_expression LESSEQUAL additive_expression
                     {
                          $$ = new BinaryExpression( yylineno, AstNode::LEOP, $1, $3 );
                     }
                     ;

additive_expression: multiplicative_expression
                   {
                   $$ = $1;
                   }
                   |
                   additive_expression PLUS multiplicative_expression
                      {
                          $$ = new BinaryExpression( yylineno, AstNode::ADDOP, $1, $3 );
                      }
                   |
                   additive_expression MINUS multiplicative_expression
                      {
                          $$ = new BinaryExpression( yylineno, AstNode::SUBOP, $1, $3 );
                      }
                   ;

multiplicative_expression: unary_expression
                         {
                         $$ = $1;
                         }
                         |
                         multiplicative_expression MUL unary_expression
                         {
                            $$ = new BinaryExpression( yylineno, AstNode::MULOP, $1, $3 );
                         }
                         |
                         multiplicative_expression DIVIDE unary_expression
                         {
                            $$ = new BinaryExpression( yylineno, AstNode::DIVOP, $1, $3 );
                         }
                         ;

unary_expression: primary_expression
                {
                $$ = $1;
                }
                |
                PLUS unary_expression
                {
                    $$ = new UnaryExpression(yylineno, AstNode::ADDOP, $2);
                }
                |
                unary_expression INCREMENT
                {
                    $$ = new UnaryExpression(yylineno, AstNode::INCOP, $1, true);
                }
                |
                MINUS unary_expression
                {
                    $$ = new UnaryExpression(yylineno, AstNode::SUBOP, $2);
                }
                |
                unary_expression DECREMENT
                {
                    $$ = new UnaryExpression(yylineno, AstNode::DECOP, $1, true);
                }
                |
                LPAR type RPAR unary_expression
                {
                    $$ = new CastExpression(yylineno, $2, $4);
                }
                ;

primary_expression: /*INTLITERAL
                   {
                   $$ = new LiteralExpression(yylineno, $1, AstNode::TINT);
                   }
                   |
                   FLOATLITERAL
                   {
                   $$ = new LiteralExpression(yylineno, $1, AstNode::TFLOAT);
                   }
                   |
                   STRING
                   {
                   $$ = new LiteralExpression(yylineno, $1, AstNode::TSTRING);
                   }
                   |
                   NULL_
                   {
                   $$ = new LiteralExpression(yylineno, $1, AstNode::TREF);
                   }
                   */
                  literal
                  {
                    $$ = $1;
                  }
                  |
                  IDENT
                  {
                  $$ = new ReferenceExpression(yylineno, $1);
                  //Entry* e = table->lookup($1);
                  //((ReferenceExpression*)$$)->setEntry(e);
                  }
                  |
                  IDENT LBRACKET primary_expression RBRACKET
                  {
                    $$ = new ReferenceExpression(yylineno, $1, $3);
                    //Entry* e = table->lookup($1);
                    //((ReferenceExpression*)$$)->setEntry(e);
                  }
                  |
                  method_invocation
                  {
                  $$ = $1;
                  }
                  |
                  LPAR expression RPAR
                  {
                  $$ = $2;
                  }
                  |
                  NEW INT LBRACKET primary_expression RBRACKET
                  {
                  $$ = new NewExpression(yylineno, AstNode::TINTA, $4);
                  }
                  |
                  NEW FLOAT LBRACKET primary_expression RBRACKET
                  {
                  $$ = new NewExpression(yylineno, AstNode::TFLOATA, $4);
                  }
                  ;

literal: INTLITERAL
       {
       $$ = new LiteralExpression(yylineno, $1, AstNode::TINT);
       }
       |
       FLOATLITERAL
       {
       $$ = new LiteralExpression(yylineno, $1, AstNode::TFLOAT);
       }
       |
       STRING
       {
       $$ = new LiteralExpression(yylineno, $1, AstNode::TSTRING);
       }
       |
       NULL_
       {
       $$ = new LiteralExpression(yylineno, $1, AstNode::TREF);
       }
       ;

empty: ;

%%

void
yyerror( const char *msg )
{
  printf("Line %d at \"%s\": %s\n", yylineno, yytext, msg);
  yyclearin;
  yyerrok;
}

void error(const char *msg){
    yyerror(msg);
}

void error_semi(){
    error("Expecting a SEMI here");
}

void clear_error(){
    yyclearin;
    yyerrok;
}
