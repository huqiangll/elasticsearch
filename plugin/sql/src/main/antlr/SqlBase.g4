/*
 * ELASTICSEARCH CONFIDENTIAL
 * __________________
 *
 *  [2017] Elasticsearch Incorporated. All Rights Reserved.
 *
 * NOTICE:  All information contained herein is, and remains
 * the property of Elasticsearch Incorporated and its suppliers,
 * if any.  The intellectual and technical concepts contained
 * herein are proprietary to Elasticsearch Incorporated
 * and its suppliers and may be covered by U.S. and Foreign Patents,
 * patents in process, and are protected by trade secret or copyright law.
 * Dissemination of this information or reproduction of this material
 * is strictly forbidden unless prior written permission is obtained
 * from Elasticsearch Incorporated.
 */

/** Fork from Presto Parser - significantly trimmed down and adjusted for ES */
/** presto-parser/src/main/antlr4/com/facebook/presto/sql/parser/SqlBase.g4 grammar */

grammar SqlBase;

tokens {
    DELIMITER
}

singleStatement
    : statement EOF
    ;

singleExpression
    : expression EOF
    ;

statement
    : query                                                                                               #statementDefault
    | EXPLAIN
        ('('
        (
          PLAN type=(PARSED | ANALYZED | OPTIMIZED | MAPPED | EXECUTABLE | ALL)
        | FORMAT format=(TEXT | GRAPHVIZ)
        | VERIFY verify=booleanValue
        )*
        ')')?
        statement                                                                                         #explain
    | DEBUG
        ('('
        (
          PLAN type=(ANALYZED | OPTIMIZED)
        | FORMAT format=(TEXT | GRAPHVIZ)
        )*
        ')')?
        statement                                                                                         #debug
    | SHOW TABLES (LIKE? pattern)?                                                                        #showTables
    | SHOW COLUMNS (FROM | IN) tableIdentifier                                                            #showColumns
    | (DESCRIBE | DESC) tableIdentifier                                                                   #showColumns
    | SHOW FUNCTIONS (LIKE? pattern)?                                                                     #showFunctions
    | SHOW SCHEMAS                                                                                        #showSchemas
    | SYS TABLES (LIKE? pattern)?                                                                         #sysTables
    | SYS COLUMNS (TABLES LIKE? indexPattern=pattern)? (LIKE? columnPattern=pattern)?                     #sysColumns
    | SYS TYPES                                                                                           #sysTypes  
    ;
    
query
    : (WITH namedQuery (',' namedQuery)*)? queryNoWith
    ;

queryNoWith
    : queryTerm
    /** we could add sort by - sort per partition */
      (ORDER BY orderBy (',' orderBy)*)?
      (LIMIT limit=(INTEGER_VALUE | ALL))?
    ;

queryTerm
    : querySpecification                   #queryPrimaryDefault
    | '(' queryNoWith  ')'                 #subquery
    ;

orderBy
    : expression ordering=(ASC | DESC)?
    ;

querySpecification
    : SELECT setQuantifier? selectItem (',' selectItem)*
      fromClause?
      (WHERE where=booleanExpression)?
      (GROUP BY groupBy)?
      (HAVING having=booleanExpression)?
    ;

fromClause
    : FROM relation (',' relation)*
    ;

groupBy
    : setQuantifier? groupingElement (',' groupingElement)*
    ;

groupingElement
    : groupingExpressions                         #singleGroupingSet
    ;

groupingExpressions
    : '(' (expression (',' expression)*)? ')'
    | expression
    ;

namedQuery
    : name=identifier AS '(' queryNoWith ')'
    ;

setQuantifier
    : DISTINCT
    | ALL
    ;

selectItem
    : expression (AS? identifier)?                #selectExpression
    ;

relation
    : relationPrimary joinRelation*
    ;

joinRelation
    : (joinType) JOIN right=relationPrimary joinCriteria?
    | NATURAL joinType JOIN right=relationPrimary
    ;

joinType
    : INNER?
    | LEFT OUTER?
    | RIGHT OUTER?
    | FULL OUTER?
    ;

joinCriteria
    : ON booleanExpression
    | USING '(' identifier (',' identifier)* ')'
    ;

relationPrimary
    : tableIdentifier (AS? qualifiedName)?                            #tableName
    | '(' queryNoWith ')' (AS? qualifiedName)?                        #aliasedQuery
    | '(' relation ')' (AS? qualifiedName)?                           #aliasedRelation
    ;

expression
    : booleanExpression
    ;

booleanExpression
    : NOT booleanExpression                                                                 #logicalNot
    | EXISTS '(' query ')'                                                                  #exists
    | QUERY '(' queryString=STRING (',' options=STRING)* ')'                                #stringQuery
    | MATCH '(' singleField=qualifiedName ',' queryString=STRING (',' options=STRING)* ')'  #matchQuery
    | MATCH '(' multiFields=STRING ',' queryString=STRING (',' options=STRING)* ')'         #multiMatchQuery
    | predicated                                                                            #booleanDefault
    | left=booleanExpression operator=AND right=booleanExpression                           #logicalBinary
    | left=booleanExpression operator=OR right=booleanExpression                            #logicalBinary
    ;

// workaround for:
//  https://github.com/antlr/antlr4/issues/780
//  https://github.com/antlr/antlr4/issues/781
predicated
    : valueExpression predicate?
    ;

// dedicated calls for each branch are not used to reuse the NOT handling across them
// instead the property kind is used to differentiate
predicate
    : NOT? kind=BETWEEN lower=valueExpression AND upper=valueExpression
    | NOT? kind=IN '(' expression (',' expression)* ')'
    | NOT? kind=IN '(' query ')'
    | NOT? kind=LIKE pattern
    | NOT? kind=RLIKE regex=STRING
    | IS NOT? kind=NULL
    ;

pattern
    : value=STRING (ESCAPE escape=STRING)?
    ;

valueExpression
    : primaryExpression                                                                 #valueExpressionDefault
    | operator=(MINUS | PLUS) valueExpression                                           #arithmeticUnary
    | left=valueExpression operator=(ASTERISK | SLASH | PERCENT) right=valueExpression  #arithmeticBinary
    | left=valueExpression operator=(PLUS | MINUS) right=valueExpression                #arithmeticBinary
    | left=valueExpression comparisonOperator right=valueExpression                     #comparison
    ;

primaryExpression
    : CAST '(' expression AS dataType ')'                                            #cast
    | EXTRACT '(' field=identifier FROM valueExpression ')'                          #extract
    | constant                                                                       #constantDefault
    | ASTERISK                                                                       #star
    | (qualifiedName DOT)? ASTERISK                                                  #star
    | identifier '(' (setQuantifier? expression (',' expression)*)? ')'              #functionCall
    | '(' query ')'                                                                  #subqueryExpression
    | identifier                                                                     #columnReference
    | qualifiedName                                                                  #dereference
    | '(' expression ')'                                                             #parenthesizedExpression
    ;

    
constant
    : NULL                                                                                     #nullLiteral
    | number                                                                                   #numericLiteral
    | booleanValue                                                                             #booleanLiteral
    | STRING+                                                                                  #stringLiteral
    ;

comparisonOperator
    : EQ | NEQ | LT | LTE | GT | GTE
    ;

booleanValue
    : TRUE | FALSE
    ;

dataType
    : identifier                                                                      #primitiveDataType
    ;

qualifiedName
    : (identifier DOT)* identifier
    ;

identifier
    : quoteIdentifier
    | unquoteIdentifier
    ;

tableIdentifier
    : TABLE_IDENTIFIER
    | identifier
    ;

quoteIdentifier
    : QUOTED_IDENTIFIER      #quotedIdentifier
    | BACKQUOTED_IDENTIFIER  #backQuotedIdentifier
    ;

unquoteIdentifier
    : IDENTIFIER             #unquotedIdentifier
    | nonReserved            #unquotedIdentifier
    | DIGIT_IDENTIFIER       #digitIdentifier
    ;

number
    : DECIMAL_VALUE  #decimalLiteral
    | INTEGER_VALUE  #integerLiteral
    ;

// http://developer.mimer.se/validator/sql-reserved-words.tml
nonReserved
    : ANALYZE | ANALYZED 
    | COLUMNS 
    | DEBUG 
    | EXECUTABLE | EXPLAIN 
    | FORMAT | FUNCTIONS 
    | GRAPHVIZ 
    | MAPPED 
    | OPTIMIZED 
    | PARSED | PHYSICAL | PLAN 
    | QUERY 
    | RLIKE
    | SCHEMAS | SHOW | SYS
    | TABLES | TEXT | TYPES
    | VERIFY
    ;

ALL: 'ALL';
ANALYZE: 'ANALYZE';
ANALYZED: 'ANALYZED';
AND: 'AND';
ANY: 'ANY';
AS: 'AS';
ASC: 'ASC';
BETWEEN: 'BETWEEN';
BY: 'BY';
CAST: 'CAST';
COLUMNS: 'COLUMNS';
DEBUG: 'DEBUG';
DESC: 'DESC';
DESCRIBE: 'DESCRIBE';
DISTINCT: 'DISTINCT';
ESCAPE: 'ESCAPE';
EXECUTABLE: 'EXECUTABLE';
EXISTS: 'EXISTS';
EXPLAIN: 'EXPLAIN';
EXTRACT: 'EXTRACT';
FALSE: 'FALSE';
FORMAT: 'FORMAT';
FROM: 'FROM';
FULL: 'FULL';
FUNCTIONS: 'FUNCTIONS';
GRAPHVIZ: 'GRAPHVIZ';
GROUP: 'GROUP';
HAVING: 'HAVING';
IN: 'IN';
INNER: 'INNER';
IS: 'IS';
JOIN: 'JOIN';
LEFT: 'LEFT';
LIKE: 'LIKE';
LIMIT: 'LIMIT';
MAPPED: 'MAPPED';
MATCH: 'MATCH';
NATURAL: 'NATURAL';
NOT: 'NOT';
NULL: 'NULL';
ON: 'ON';
OPTIMIZED: 'OPTIMIZED';
OR: 'OR';
ORDER: 'ORDER';
OUTER: 'OUTER';
PARSED: 'PARSED';
PHYSICAL: 'PHYSICAL';
PLAN: 'PLAN';
RIGHT: 'RIGHT';
RLIKE: 'RLIKE';
QUERY: 'QUERY';
SCHEMAS: 'SCHEMAS';
SELECT: 'SELECT';
SHOW: 'SHOW';
SYS: 'SYS';
TABLES: 'TABLES';
TEXT: 'TEXT';
TRUE: 'TRUE';
TYPES: 'TYPES';
USING: 'USING';
VERIFY: 'VERIFY';
WHERE: 'WHERE';
WITH: 'WITH';

EQ  : '=';
NEQ : '<>' | '!=' | '<=>';
LT  : '<';
LTE : '<=';
GT  : '>';
GTE : '>=';

PLUS: '+';
MINUS: '-';
ASTERISK: '*';
SLASH: '/';
PERCENT: '%';
CONCAT: '||';
DOT: '.';

STRING
    : '\'' ( ~'\'' | '\'\'' )* '\''
    ;

INTEGER_VALUE
    : DIGIT+
    ;

DECIMAL_VALUE
    : DIGIT+ DOT DIGIT*
    | DOT DIGIT+
    | DIGIT+ (DOT DIGIT*)? EXPONENT
    | DOT DIGIT+ EXPONENT
    ;

IDENTIFIER
    : (LETTER | '_') (LETTER | DIGIT | '_' | '@' )*
    ;

DIGIT_IDENTIFIER
    : DIGIT (LETTER | DIGIT | '_' | '@' | ':')+
    ;

TABLE_IDENTIFIER
    : (LETTER | DIGIT | '_' | '@' | ASTERISK)+
    ;

QUOTED_IDENTIFIER
    : '"' ( ~'"' | '""' )* '"'
    ;

BACKQUOTED_IDENTIFIER
    : '`' ( ~'`' | '``' )* '`'
    ;

fragment EXPONENT
    : 'E' [+-]? DIGIT+
    ;

fragment DIGIT
    : [0-9]
    ;

fragment LETTER
    : [A-Z]
    ;

SIMPLE_COMMENT
    : '--' ~[\r\n]* '\r'? '\n'? -> channel(HIDDEN)
    ;

BRACKETED_COMMENT
    : '/*' (BRACKETED_COMMENT|.)*? '*/' -> channel(HIDDEN)
    ;

WS
    : [ \r\n\t]+ -> channel(HIDDEN)
    ;

// Catch-all for anything we can't recognize.
// We use this to be able to ignore and recover all the text
// when splitting statements with DelimiterLexer
UNRECOGNIZED
    : .
    ;
