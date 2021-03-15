@[system; "l yaml.q"; {-1"Failed to load yaml.q: ",x; exit 0}]


opt:.Q.opt[.z.x];
.test.debug:$[`debug in key opt; 1b; 0b];
.test.testDir:`:tests;
.test.testCases:("SSS*"; enlist ",")0: ` sv .test.testDir,`testCases.csv;
exists:{not ()~key x};
if[not exists .test.testDir; '"test dir ",string[.test.testDir]," doesn't exist"; exit 0];
.log.debug:{[msg] if[.test.debug; -1 string[.z.p]," | DEBUG | ",msg; :msg];};

equals:{[a; b]
    t:type each (a;b);
    str:.Q.s (a;b);
    / qYaml converts to kdb timestamps, json keeps as iso format - compare accoringly
    if[all t=-12 10;
        sa:.h.iso8601[a]; sb:$["Z"=last[b]; -1_b; b];
        m:sb~count[sb]#sa;
        .log.debug (("failed";"passed")@m)," match on iso timestamp - ", str;
        :m
        ];
    if[all t=10 -12;
        sb:.h.iso8601[b]; sa:$["Z"=last[a]; -1_a; a];
        m:sa~count[sa]#sb;
        .log.debug (("failed";"passed")@m)," match on iso timestamp - ", str;
        :m
        ];

    if[asc[(a;b)]~asc((::);0n); 
        .log.debug"Matched null values - ", str;
        :1b
        ];
    if[count[a]<>count b; 
        .log.debug "Different counts for values - ",str;
        :0b];

    if[all t < 0;
        m:a=b;
        .log.debug (("failed";"passed")@m)," match on atomic values - ", str;
        :m
        ];

    if[all t within 0 20;
        :all .z.s'[a;b];
        ];

    if[all t=99h; / dict
        a:asc[key a]#a; b:asc[key b]#b; / sort because order doesn't matter in a dict
        :$[key[a]~key[b]; :.z.s[value a;value b]; 0b];
        ];

    if[all t=98h; / table
        :.z.s[flip a; flip b]
        ];

    if[all t=0; :all .z.s'[a;b]];

    :a~b
    };



run:{[test]
    testFile:` sv .test.testDir,test;
    res:@[{(.yml.load x; 1b)}; testFile; {("Failed to parse: ",x; 0b)}];
    if[.test.debug & not res[1]; 
        .log.debug"Failed to load yaml file ",string[testFile];
        .yml.load testFile];
    / get the expected json file if it exists
    tc:select from .test.testCases where input = test;
    if[0=count tc; 'string[test]," not found in testCases.csv"];
    ex:` sv .test.testDir,first[tc]`expected; t:first[tc]`outputType;
    r:$[t=`json; {.j.k raze read0 x}; t=`q; {value raze read0 x}; {[x;e] '"could not parse outputType ",string[x]}[t;]];
    output:.[{[f;x] (f x; 1b)};(r;ex); {("Failed to parse expected file ",string[x],": ",y;0b)}[ex;]];
    expected:output[0];
    loadMatch:equals[actual:res[0];expected];
    if[.test.debug&not loadMatch; 
        .log.debug"Actual does not match expected for ",string[test],"\n\n";
        .log.debug"Actual:\n\n",.Q.s[a:actual],"\n\n";
        .log.debug"Expected:\n\n",.Q.s[b:expected],"\n";
        s:read0 testFile; / helpful for stepping into .yml.parse
        'debug];

    dump:@[{(.yml.dump x; 1b)}; expected; {("Failed to dump: ",x; 0b)}];
    if[.test.debug & not dump[1]; 
        .log.debug"Failed to dump q to yaml for ",string[testFile];
        .yml.dump expected];

    ld:@[{(.yml.load x 0; x[1]&1b)}; dump; {("Failed to load dump: ",x; 0b)}];
    if[.test.debug & not ld[1]; 
        .log.debug"Failed to load dump of yaml into q for ",string[testFile];
        .yml.load dump 0];

    dumpMatch:equals[ld 0; expected];
    if[.test.debug&not dumpMatch;
        .log.debug"dumped yaml does not match expected when loaded back in\n";
        .log.debug"Actual:\n\n",.Q.s[a:actual],"\n\n";
        .log.debug"Expected:\n\n",.Q.s[b:expected],"\n\n";
        'debug];

    pass:all (res 1; dump 1; ld 1; loadMatch; dumpMatch);

    :`test`loadedOk`dumpOk`loadMatch`dumpMatch`pass`expected`actual`comment!(test; res[1]; dump[1]&ld[1]; loadMatch; dumpMatch; pass; expected ;actual; first tc`comment)
    };

runAll:{[debug]
    debugOrig:@[value;`.test.debug; 0b]; / orig debug val
    Porig:string system"P"; system"P 12"; / set larger precision
    .test.debug:$[1b~debug; 1b; 0b~debug; 0b; debugOrig];
    tests:exec input from .test.testCases;
    res:run each tests;
    .test.debug:debugOrig;
    system"P ",Porig;
    :res
    };

if[`run in key opt; 
    res:runAll[];
    -1 .Q.s res
    ];

/ ------------------- HTML reports ----------------------

.h.saOrig:.h.sa;

.h.sa:.h.saOrig,:"table {
   font-family: arial, sans-serif;
   border-collapse: collapse;
   width: 100%;
 }
 
 td, th {
   border: 1px solid #dddddd;
   text-align: left;
   padding: 8px;
 }
 
 tr:nth-child(even) {
   background-color: #dddddd;
 }"

.h.table:{[t]
    t:0!t;
    head:.h.htc[`tr;] 
        raze .h.htc[`th;]each string cols t;
    rows:raze {.h.htc[`tr;] raze .h.htc[`td;] each {$[10h=type x; x; .j.j x]}each value x}each t;
    :.h.htc[`table; head,rows]
    };

.rpt.reports:`tests`viewer;

.rpt.ph:{ 
    x:"?" vs .h.uh $[type x;x; first x];
    req:`$first x; args:1_x;
    :$[null req; 
            .h.hy[`htm].h.fram["qYaml"; string[.rpt.reports]; ("menu"; "tests")];
       req=`menu; 
            .h.hp {.h.hb["/",x;x]}each string[.rpt.reports];
        req in .rpt.reports;
            .h.hp enlist @[value; (` sv `.rpt,req; args); {[x;e]"error running ",x,": ",e}[string req;]];
        .z.phOrig x
    ];
 };
    

.rpt.tests:{[args]
    ok:"&#9989";fail:"&#10060"; status:10b!(ok;fail);
    res:select test, loadedOk, dumpOk, loadMatch, dumpMatch, pass, comment from runAll[0b];
    s:exec totalTests:count[i], passed:"j"$sum pass, failed:"j"$sum not pass from res;
    summary:.h.htc[`h1; "Summary"] , .h.htc[`p; .Q.s s];
    res:update status@loadedOk, status@dumpOk, status@loadMatch, status@dumpMatch, status@pass from res;
    res:update run:{.h.htac[`form;enlist[`action]!enlist`tests;] .h.htac[`input; `type`name`value!(`submit;x;"Run");""]}each test from res;
    out:.h.htac[`div; enlist[`style]!enlist "height:60%;width:60%;border:1px solid black;overflow:auto;";].h.table res;
    if[count args;
        test:`$first "=" vs first args;
        out:.rpt.run1test[test] , .h.br , out
        ];
    :summary , out

 };

.rpt.run1test:{[test]
    debugOrig:@[value;`.test.debug; 0b]; / orig debug val
    .test.debug:0b;
    t:run test;
    .test.debug:debugOrig;
    input:read0 ` sv .test.testDir,test;
    actual:"\n" vs .Q.s t`actual;
    expected:"\n" vs .Q.s t`expected;
    dump:@[.yml.dump; t`expected; "Failed to dump kdb to yaml: ",];

    textareas:.h.htac[`label; enlist[`for]!enlist[`input];"Input: "],
        .h.htac[`textarea; `id`name`rows`cols`readonly!(`input;`input; 10|count input; 40&2 + max count each input;`true); "\n" sv input],
        .h.htac[`label; enlist[`for]!enlist[`actual];" Actual: "],
        .h.htac[`textarea; `id`name`rows`cols`readonly!(`actual;`actual; 10|count actual;40&2 + max count each actual;`true); "\n" sv actual];

    textareas,:.h.htac[`label; enlist[`for]!enlist[`expected];" Expected: "],
    .h.htac[`textarea; `id`name`rows`cols`readonly!(`expected;`expected; 10|count expected;40&2 + max count each expected;`true); "\n" sv expected];
    
    textareas,:.h.htac[`label; enlist[`for]!enlist[`dump];" Dump: "],
    .h.htac[`textarea; `id`name`rows`cols`readonly!(`dump;`dump; 10|count dump;40&2 + max count each dump;`true); "\n" sv dump];
    :.h.htc[`h1; string[test]," - ",("failed";"passed")t`pass], .h.br ,  .h.htac[`form; enlist[`action]!enlist`run1test; textareas]

  };

.rpt.viewer:{[args]
    / .log.debug "viewer args: ",.Q.s args;
    .v.args,:enlist args;
    yaml:$[0=count args; ""; 
        ssr[;"+";" "] first cut[;a] 5 -1 + first each ss[a:first args; ]each("yaml=";"kdb=")];

    yaml:"\n" vs ssr[yaml;"\r\n"; "\n"];
    / .log.debug"YAML = ",.Q.s yaml;
    kdb:@[.yml.load; yaml; {"Failed to parse yaml: ",x}];
    / .log.debug"KDB = ",.Q.s kdb;
    textareas:.h.htac[`label; enlist[`for]!enlist[`yaml];"YAML: "],
        .h.htac[`textarea; `id`name`rows`cols!(`yaml;`yaml; 20; 40); "\n" sv yaml],
        .h.htac[`label; enlist[`for]!enlist[`kdb];" KDB: "],
        .h.htac[`textarea; `id`name`rows`cols`readonly!(`kdb;`kdb; 20; 40;`true); .Q.s kdb],
        .h.br, .h.br,
        .h.htac[`input; `type`value!(`submit`Submit);""];

    :.h.htac[`form; enlist[`action]!enlist[`viewer]; textareas]
    };


.z.phOrig:.z.ph;
.z.ph:.rpt.ph;
system"c 300 3000";

