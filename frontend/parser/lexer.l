%{
    #include <frontend/parser/yacc.h>
    #include <frontend/parser/scanner.h>
    #include <frontend/parser/location.hh>
    #include <frontend/parser/parser.h>
    #include <stdexcept>
    #include <string>
    #include <limits>      
    #include <cmath>       

    using namespace FE;

    static location loc;

    // YY_USER_ACTION 宏会自动插入到每个规则的代码块开头
    // 如下方的 "int"               { RETT(INT, loc) }
    // 实际上会被转换为
    // "int"               { loc.step(); loc.columns(yyleng); RETT(INT, loc) }
    // 这样就能自动更新 loc 的位置
    // yyleng 是当前匹配的字符串的长度
    #define YY_USER_ACTION      \
        loc.step();             \
        loc.columns(yyleng);

    #define yywrap() 1
    #define RETT(x, y) \
        return YaccParser::make_##x(y);

    #define TAB_WIDTH 4

    int handleTab();
    long long convertToInt(const char* str, const char end, bool& isLongLong);
    float convertToFloatDec(const char* str);
    float convertToFloatHex(const char* str);
%}

%option c++
%option noyywrap debug
%option yyclass="Scanner"
%option prefix="Yacc_"

/* 定义数字和指数相关的字符类 */
digit       [0-9]
hexdigit    [0-9a-fA-F]
exponent    [eE][-+]?{digit}+

/* 定义注释处理的状态 */
%x COMMENT

%%

%{
/*
在词法分析中，你需要重点考虑result的四种类型，分别为int_token, float_token, string_token, symbol_token。
之所以要定义这四种类型，是因为我们只返回这个token的类型是不够的，我们还需要知道这个token的属性。
例如我们需要知道INT_CONST具体的值是多少。
如果你需要其它 token，需要先到 yacc.y 中定义 token，然后在这里实现。

TODO(Lab1)：参考SysY2022的定义，实现更多的词法，如浮点数、十六进制/八进制数等
*/
%}

\n              {
                    loc.lines(yyleng);
                    loc.step();
                }

[ \f\r\v]+    { /* empty */ }
[\t]    {
    loc.columns(handleTab());
}

"if"                { RETT(IF, loc) }
"else"              { RETT(ELSE, loc) }
"for"               { RETT(FOR, loc) }
"while"             { RETT(WHILE, loc) }
"continue"          { RETT(CONTINUE, loc) }
"break"             { RETT(BREAK, loc) }
"switch"            { RETT(SWITCH, loc) }
"case"              { RETT(CASE, loc) }
"goto"              { RETT(GOTO, loc) }
"do"                { RETT(DO, loc) }
"return"            { RETT(RETURN, loc) }

"const"             { RETT(CONST, loc) }

";"                 { RETT(SEMICOLON, loc) }
","                 { RETT(COMMA, loc) }

"int"   { RETT(INT, loc) }
"float"   { RETT(FLOAT, loc) }

"//".*              { 
    auto str = std::string(yytext);
    // return YaccParser::make_SLASH_COMMENT(str, loc);  //思考为什么要把这一行注释掉
                                                         //答：因为不需要把注释的内容传递给语法分析器​​
}

"/*" {
    BEGIN(COMMENT);  // 进入注释状态
}

<COMMENT>"*/" {
    BEGIN(INITIAL);  // 退出注释状态，返回初始状态
}

<COMMENT>[^*\n]+ {
    // 注释中的普通字符，忽略
}

<COMMENT>"*" {
    // 注释中的单个星号，忽略
}

<COMMENT>\n {
    // 注释中的换行符，需要更新行号
    loc.lines(1);
    loc.step();
}

<COMMENT><<EOF>> {
    _parser.reportError(loc, "Unterminated comment");
    BEGIN(INITIAL);
    return YaccParser::make_ERR_TOKEN("Unterminated comment", loc);
}

"+"                 { RETT(ADD, loc) }
"-"                 { RETT(SUB, loc) }
"*"                 { RETT(MUL, loc) }
"/"                 { RETT(DIV, loc) }
"%"                 { RETT(MOD, loc) }

"=="                { RETT(EQ, loc) }
"!="                { RETT(NE, loc) }
"<"                 { RETT(LT, loc) }
"<="                { RETT(LE, loc) }
">"                 { RETT(GT, loc) }
">="                { RETT(GE, loc) }

"&&"                { RETT(AND, loc) }
"||"                { RETT(OR, loc) }
"!"                 { RETT(NOT, loc) }

"="                 { RETT(ASSIGN, loc) }

"&"                 { RETT(BITAND, loc) }
"|"                 { RETT(BITOR, loc) }
"^"                 { RETT(BITXOR, loc) }
"~"                 { RETT(BITNOT, loc) }
"<<"                { RETT(SHL, loc) }
">>"                { RETT(SHR, loc) }

"+="                { RETT(ADD_ASSIGN, loc) }
"-="                { RETT(SUB_ASSIGN, loc) }
"*="                { RETT(MUL_ASSIGN, loc) }
"/="                { RETT(DIV_ASSIGN, loc) }
"%="                { RETT(MOD_ASSIGN, loc) }
"&="                { RETT(AND_ASSIGN, loc) }
"|="                { RETT(OR_ASSIGN, loc) }
"^="                { RETT(XOR_ASSIGN, loc) }
"<<="               { RETT(SHL_ASSIGN, loc) }
">>="               { RETT(SHR_ASSIGN, loc) }

"."                 { RETT(DOT, loc) }
"?"                 { RETT(QUESTION, loc) }
":"                 { RETT(COLON, loc) }
"->"                { RETT(ARROW, loc) }
"++"                { RETT(INCREMENT, loc) }
"--"                { RETT(DECREMENT, loc) }

\"[^\"]*\"          { 
    std::string str(yytext);
    if (!str.empty()) str = str.substr(1, str.size() - 2);
    return YaccParser::make_STR_CONST(str, loc); 
}

[A-Za-z_]+[A-Za-z0-9_]* {
    auto str = std::string(yytext);
    return YaccParser::make_IDENT(str, loc); 
}

{digit}+\.{digit}*({exponent})?|\.{digit}+({exponent})?|{digit}+{exponent} {
    // 浮点数常量规则 
    try {
        float result = convertToFloatDec(yytext);
        return YaccParser::make_FLOAT_CONST(result, loc);
    } catch (const std::exception& e) {
        _parser.reportError(loc, std::string("Error parsing float: ") + e.what());
        auto str = std::string(yytext);
        return YaccParser::make_ERR_TOKEN(str, loc);
    }
}

0[xX][0-9a-fA-F]+ {
    // 十六进制整数 
    try {
        bool isLL = false;
        long long result = convertToInt(yytext, '\0', isLL);
        if (isLL) return YaccParser::make_LL_CONST(result, loc);
        return YaccParser::make_INT_CONST(static_cast<int>(result), loc);
    } catch (const std::exception& e) {
        _parser.reportError(loc, std::string("Error parsing hexadecimal int: ") + e.what());
        auto str = std::string(yytext);
        return YaccParser::make_ERR_TOKEN(str, loc);
    }
}

0[0-7]+ {
    // 八进制整数 
    try {
        bool isLL = false;
        long long result = convertToInt(yytext, '\0', isLL);
        if (isLL) return YaccParser::make_LL_CONST(result, loc);
        return YaccParser::make_INT_CONST(static_cast<int>(result), loc);
    } catch (const std::exception& e) {
        _parser.reportError(loc, std::string("Error parsing octal int: ") + e.what());
        auto str = std::string(yytext);
        return YaccParser::make_ERR_TOKEN(str, loc);
    }
}

"0" {
    // 数字0
    try {
        return YaccParser::make_INT_CONST(0, loc);
    } catch (const std::exception& e) {
        _parser.reportError(loc, std::string("Error parsing integer: ") + e.what());
        auto str = std::string(yytext);
        return YaccParser::make_ERR_TOKEN(str, loc);
    }
}

[1-9][0-9]* {
    // 十进制整数 
    try {
        bool isLL = false;
        long long result = convertToInt(yytext, '\0', isLL);
        if (isLL) return YaccParser::make_LL_CONST(result, loc);
        return YaccParser::make_INT_CONST(static_cast<int>(result), loc);
    } catch (const std::exception& e) {
        _parser.reportError(loc, std::string("Error parsing hexadecimal int: ") + e.what());
        auto str = std::string(yytext);
        return YaccParser::make_ERR_TOKEN(str, loc);
    }
}

"("                 { RETT(LPAREN, loc) }
")"                 { RETT(RPAREN, loc) }
"["                 { RETT(LBRACKET, loc) }
"]"                 { RETT(RBRACKET, loc) }
"{"                 { RETT(LBRACE, loc) }
"}"                 { RETT(RBRACE, loc) }

. {
    // 错误处理 - 无法识别的字符 
    _parser.reportError(loc, std::string("Unrecognized character: ") + yytext);
    return YaccParser::make_ERR_TOKEN(std::string(yytext), loc);
}

<<EOF>>         { RETT(END, loc); }

%%

int handleTab()
{
    // 该函数用于处理制表符，根据当前位置计算制表符应占用的列数
    // 如，在TAB_WIDTH为4的情况下：
    // 对于" \t"，则会对 '\t' 返回 3
    // 对于"   \t"，则会对 '\t' 返回 1
    // 对于"    \t"，则会对 '\t' 返回 4

    int& c = loc.begin.column;
    return TAB_WIDTH - ((c - 1) % TAB_WIDTH) - 1;
}

long long convertToInt(const char* str, const char end, bool& isLongLong)
{
    // 该函数用于将字符串转换为整数，能正确处理格式无误的十进制、十六进制和八进制整数
    // 接受一个 isLongLong 引用参数，用于指示结果是否超出 int 范围

    int         base       = 10;
    long long   result     = 0;
    int         isNegative = 0;
    const char* ptr        = str;
    static int  zeroOffset = '0';
    static int  aOffset    = 'a' - 10;
    static int  AOffset    = 'A' - 10;
    int*        offset     = NULL;
    isLongLong             = false;

    if (*ptr == '-')
    {
        isNegative = 1;
        ++ptr;
    }
    else if (*ptr == '+') { ++ptr; }

    if (ptr[0] == '0' && (ptr[1] == 'x' || ptr[1] == 'X'))
    {
        base = 16;
        ptr += 2;
    }
    else if (ptr[0] == '0')
    {
        base = 8;
        ptr += 1;
    }

    while (*ptr != end)
    {
        int value = 0;

        if (base == 16)
        {
            if (*ptr >= '0' && *ptr <= '9')
                offset = &zeroOffset;
            else if (*ptr >= 'a' && *ptr <= 'f')
                offset = &aOffset;
            else if (*ptr >= 'A' && *ptr <= 'F')
                offset = &AOffset;
        }
        else { offset = &zeroOffset; }

        value  = *ptr - *offset;
        result = result * base + value;
        ++ptr;
    }

    if (isNegative) result = -result;

    if (result > std::numeric_limits<int>::max() || result < std::numeric_limits<int>::min())
    {
        isLongLong = true;
        if (result > std::numeric_limits<long long>::max() || result < std::numeric_limits<long long>::min())
        {
            throw std::out_of_range(str + std::string(" overflow or underflow for long long"));
        }
    }

    return result;
}

float convertToFloatDec(const char* str)
{
    // 该函数用于将字符串转换为浮点数，能正确处理格式无误的十进制浮点数

    const char* head = str;
    if (str == NULL) { return 0.0f; }

    int sign = 1;
    if (*str == '-')
    {
        sign = -1;
        str++;
    }
    else if (*str == '+') { str++; }

    double integerPart = 0.0;
    while (isdigit(*str))
    {
        integerPart = integerPart * 10 + (*str - '0');
        str++;
    }

    double fractionPart = 0.0;
    if (*str == '.')
    {
        str++;
        double divisor = 10.0;
        while (isdigit(*str))
        {
            fractionPart += (*str - '0') / divisor;
            divisor *= 10.0;
            str++;
        }
    }

    double value = integerPart + fractionPart;

    if (*str == 'e' || *str == 'E')
    {
        str++;
        int expSign = 1;
        if (*str == '-')
        {
            expSign = -1;
            str++;
        }
        else if (*str == '+') { str++; }

        int exponent = 0;
        while (isdigit(*str))
        {
            exponent = exponent * 10 + (*str - '0');
            str++;
        }

        value *= pow(10, expSign * exponent);
    }

    value = sign * value;

    if (value > std::numeric_limits<float>::max() || value < -std::numeric_limits<float>::max())
    {
        throw std::out_of_range(
            head + ((value > std::numeric_limits<float>::max()) ? std::string(" overflow") : std::string(" underflow")));
    }

    return static_cast<float>(value);
}

float convertToFloatHex(const char* str)
{
    // 该函数用于将字符串转换为浮点数，能正确处理格式无误的十六进制浮点数

    const char* head = str;
    if (str == NULL) { return 0.0f; }

    int sign = 1;
    if (*str == '-')
    {
        sign = -1;
        str++;
    }
    else if (*str == '+') { str++; }

    if (*str == '0' && (*(str + 1) == 'x' || *(str + 1) == 'X')) { str += 2; }

    unsigned long long integerPart = 0;
    while (isxdigit(*str))
    {
        int digit = 0;
        if (isdigit(*str)) { digit = (*str - '0'); }
        else if (*str >= 'a' && *str <= 'f') { digit = (*str - 'a' + 10); }
        else if (*str >= 'A' && *str <= 'F') { digit = (*str - 'A' + 10); }
        integerPart = integerPart * 16 + digit;
        str++;
    }

    double fractionPart = 0.0;
    if (*str == '.')
    {
        str++;
        unsigned long long numerator   = 0;
        unsigned long long denominator = 1;
        while (isxdigit(*str))
        {
            int digit = 0;
            if (isdigit(*str)) { digit = (*str - '0'); }
            else if (*str >= 'a' && *str <= 'f') { digit = (*str - 'a' + 10); }
            else if (*str >= 'A' && *str <= 'F') { digit = (*str - 'A' + 10); }
            numerator = numerator * 16 + digit;
            denominator *= 16;
            str++;
        }
        fractionPart = (double)numerator / (double)denominator;
    }

    double value = (double)integerPart + fractionPart;

    if (*str == 'p' || *str == 'P')
    {
        str++;
        int expSign = 1;
        if (*str == '-')
        {
            expSign = -1;
            str++;
        }
        else if (*str == '+') { str++; }

        int exponent = 0;
        while (isdigit(*str))
        {
            exponent = exponent * 10 + (*str - '0');
            str++;
        }

        value *= pow(2, expSign * exponent);
    }

    value = sign * value;

    if (value > std::numeric_limits<float>::max() || value < -std::numeric_limits<float>::max())
    {
        throw std::out_of_range(
            head + ((value > std::numeric_limits<float>::max()) ? std::string(" overflow") : std::string(" underflow")));
    }

    return static_cast<float>(value);
}
