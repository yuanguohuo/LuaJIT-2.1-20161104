--   Yuanguo:
--   v: variable table;
--   const_str: string constant table;
--   const_num: number constant table;
--   const_tab: table constant table;
--    
--   Note: I do not know how these table are placed; maybe there is only one constant 
--   table, that is indexed in different ways.

================test.lua==============
a=10
b=20
c=a+b
return a,b,c

==========luajit -bl test.lua=========
-- BYTECODE -- test.lua:0-5
0001    KSHORT   0  10             --Yuanguo: v[0] = 10;         '0' is variable slot number; 10 is signed literal;
0002    GSET     0   0      ; "a"  --Yuanguo: _G["a"] = v[0];    1st '0' is variable slot number; 2nd '0' is index of string constant table (const_str[0]="a");
0003    KSHORT   0  20             --Yuanguo: v[0] = 20;
0004    GSET     0   1      ; "b"  --Yuanguo: _G["b"] = v[0];    const_str[1]="b";
0005    GGET     0   0      ; "a"  --Yuanguo: v[0] = _G["a"];    1st '0' is variable slot number; 2nd '0' is index of string constant table (const_str[0]="a");
0006    GGET     1   1      ; "b"  --Yuanguo: v[1] = _G["b"];    const_str[1]="b";
0007    ADDVV    0   0   1         --Yuanguo: v[0] = v[0]+v[1];  '0', '0', '1' are all variable slot numbers;
0008    GSET     0   2      ; "c"  --Yuanguo: _G["c"] = v[0];    const_str[2]="c";
0009    GGET     0   0      ; "a"  --Yuanguo: v[0] = _G["a"];    const_str[0]="a";
0010    GGET     1   1      ; "b"  --Yuanguo: v[1] = _G["b"];    const_str[1]="b"; 
0011    GGET     2   2      ; "c"  --Yuanguo: v[2] = _G["c"];    const_str[2]="c";
0012    RET      0   4             --Yuanguo: ret v[0], 4-1;     return 4-1=3 values starting at v[0], that is v[0],v[1],v[2];



===============test1.lua==============
a=4
for i=2,9 do
    a=a+1
end
return a

=========luajit -bl test1.lua=========
-- BYTECODE -- test1.lua:0-6
0001    KSHORT   0   4                -- v[0] = 4
0002    GSET     0   0      ; "a"     -- _G["a"] = v[0]
0003    KSHORT   0   2                -- v[0] = 2   Yuanguo: numeric-for-loop start
0004    KSHORT   1   9                -- v[1] = 9   Yuanguo: numeric-for-loop end
0005    KSHORT   2   1                -- v[2] = 1   Yuanguo: numeric-for-loop step
0006    FORI     0 => 0011            -- Yuanguo: numeric-for-loop initialization; if TEST false, jumps to 0011; else, 0007
0007 => GGET     4   0      ; "a"     -- v[4] = _G["a"]
0008    ADDVN    4   4   0  ; 1       -- v[4] = v[4] + 1    Yuanguo: '0' is index of number constant table (const_num[0]=1)
0009    GSET     4   0      ; "a"     -- _G["a"] = v[4]
0010    FORL     0 => 0007            -- Yuanguo: numeric-for-loop; if TEST true, jumps to 0007; else, 0011
0011 => GGET     0   0      ; "a"     -- v[0] = _G["a"]
0012    RET1     0   2                -- ret v[0], 2-1;     Yuanguo: return 2-1=1 value starting at v[0];



===============test2.lua==============
foo = 0
bar = ""
mylist={"xx","yy","zz"}
for i,v in pairs(mylist) do
    foo = foo + i
    bar = bar .. v
end
return foo, bar

=========luajit -bl test2.lua=========
-- BYTECODE -- test2.lua:0-10
0001    KSHORT   0   0                  -- v[0] = 0
0002    GSET     0   0      ; "foo"     -- _G["foo"] = v[0]
0003    KSTR     0   1      ; ""        -- v[0] = ""    Yuanguo: const_str[1]=""
0004    GSET     0   2      ; "bar"     -- _G["bar"] = v[0]
0005    TDUP     0   3                  -- v[0] = duplicated template table (const_tab[3]={"xx","yy","zz"});
0006    GSET     0   4      ; "mylist"  -- _G["mylist"] = v[0]
0007    GGET     0   5      ; "pairs"   -- v[0] = _G["pairs"]   Yuanguo: const_str[5]="pairs"; _G["pairs"] is the 'pairs' function;
0008    GGET     1   4      ; "mylist"  -- v[1] = _G["mylist"]

0009    CALL     0   4   2              -- v[0],v[1],v[2] = v[0](v[1])   Yuanguo: before the CALL, v[0] is the 'pairs' function,
                                        --        v[1] is the argument table ('mylist'). Because 'pairs' function returns three  
                                        --        values: a. the 'next' function (iterator); b. the argument table; c. nil (control variable);
                                        --        so, after CALL, v[0] is the iterator ('next' function), v[1] is the argument table (mylist)
                                        --        and v[2] is the control variable (nil);
                                        
0010    ISNEXT   3 => 0018              -- ISNEXT verifies iterator is 'next' function, argument is table and control variable is nil (because
                                        --        of the CALL above, the 3 conditions hold). Then it sets the lowest 32 bits of the control variable
                                        --        to 0 and jumps to iterator call, that is line "0018";

0011 => GGET     5   0      ; "foo"     -- v[5] = _G["foo"]
0012    ADDVV    5   5   3              -- v[5] = v[5] + v[3]   ----- v[3] is the 1st return value of 'next' function;
0013    GSET     5   0      ; "foo"     -- _G["foo"] = v[5]
0014    GGET     5   2      ; "bar"     -- v[5] = _G["bar"]
0015    MOV      6   4                  -- v[6] = v[4]          ----- v[4] is the 2nd return value of 'next' function;
0016    CAT      5   5   6              -- v[5] = v[5] .. v[6]
0017    GSET     5   2      ; "bar"     -- _G["bar"] = v[5]
0018 => ITERN    3   3   3              -- v[3],v[4],v[5] = v[0],v[1],v[2];  v[3],v[4] = v[3](v[4],v[5]) --> i,v = next(argument-table, control-variable)
0019    ITERL    3 => 0011              -- iterator loop; if TEST true, jumps to 0011; else, 0020;
0020    GGET     0   0      ; "foo"     -- v[0] = _G["foo"]
0021    GGET     1   2      ; "bar"     -- v[1] = _G["bar"]
0022    RET      0   3                  -- ret v[0],v[1]


===============test3.lua==============
function myMult(x,y)
    return x*y
end

foo = 12
bar = 7
r = myMult(foo,bar)
return foo,bar,r


=========luajit -bl test3.lua=========
-- BYTECODE -- test3.lua:1-3
0001    MULVV    2   0   1     -- v[2] = v[0] * v[1]
0002    RET1     2   2         -- ret v[2]

-- BYTECODE -- test3.lua:0-9
0001    FNEW     0   0      ; test3.lua:1    -- v[0] = Create new closure from prototype 0 (what is prototype 0? Yuanguo: 2nd '0' should be index of prototype table)
0002    GSET     0   1      ; "myMult"       -- _G["myMult"] = v[0];   
0003    KSHORT   0  12                       -- v[0] = 12
0004    GSET     0   2      ; "foo"          -- _G["foo"] = v[0]
0005    KSHORT   0   7                       -- v[0] = 7
0006    GSET     0   3      ; "bar"          -- _G["bar"] = v[0]
0007    GGET     0   1      ; "myMult"       -- v[0] = _G["myMult"]
0008    GGET     1   2      ; "foo"          -- v[1] = _G["foo"]
0009    GGET     2   3      ; "bar"          -- v[2] = _G["bar"]
0010    CALL     0   2   3                   -- v[0] = v[0](v[1],v[2])
0011    GSET     0   4      ; "r"            -- _G["r"] = v[0]
0012    GGET     0   2      ; "foo"          -- v[0] = _G["foo"]
0013    GGET     1   3      ; "bar"          -- v[1] = _G["bar"]
0014    GGET     2   4      ; "r"            -- v[2] = _G["r"]
0015    UCLO     0 => 0016                   -- Close upvalues for slots ≥ 0 and jump to 0016 (???)
0016 => RET      0   4                       -- ret v[0],v[1],v[2]

