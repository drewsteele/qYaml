@[system; "l yaml.q"; {-1"Failed to load yaml.q: ",x; exit 0}]

.log.debug:{[msg] -1 string[.z.p]," | DEBUG | ",msg; :msg};

opt:.Q.opt[.z.x];
.test.debug:$[`debug in key opt; 1b; 0b];
.test.testDir:`:tests;
exists:{not ()~key x};
if[not exists .test.testDir; '"test dir ",string[.test.testDir]," doesn't exist"; exit 0];

equals:{[a; b]
    if[count[a]<>count b; :0b];
    t:type each (a;b);
    if[all t < 0;
        :a=b
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
    res:@[{(.yml.load x; 1b)}; test; {("Failed to parse: ",x; 0b)}];
    if[.test.debug & not res[1]; 
        .log.debug"Failed to load yaml file ",string[test];
        .yml.load test];
    / get the expected json file if it exists
    tn:first ` vs last ` vs test;
    jn:` sv (.test.testDir;`json; ` sv tn,`json);
    e:exists jn; 
    json:@[{(.j.k raze read0 x;1b)};jn; {("Failed to parse json file ",string[x],": ",y;0b)}[jn;]];
    expected:json[0];
    pass:e&equals[actual:res[0];expected];
    if[.test.debug&e&not pass; 
        .log.debug"Actual does not match expected for ",string[test],"\n\n";
        .log.debug"Actual:\n\n",.Q.s[a:actual],"\n\n";
        .log.debug"Expected:\n\n",.Q.s[b:expected],"\n";
        s:read0 test; / helpful for stepping into .yml.parse
        'debug];

    :`test`loadedOk`pass`expected`actual!(test; res[1]; pass; expected ;actual)
    };

runAll:{[debug]
    debugOrig:@[value;`.test.debug; 0b]; / orig debug val
    .test.debug:$[1b~debug; 1b; 0b~debug; 0b; debugOrig];
    p:` sv .test.testDir,`yaml;
    tests:` sv/: p,/:{x where x like "*.yml"}key p;
    res:run each tests;
    .test.debug:debugOrig;
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
    res:select test, loadedOk, pass from runAll[0b];
    res:update status@loadedOk, status@pass from res;
    res:update run:{.h.htac[`form;enlist[`action]!enlist`tests;] .h.htac[`input; `type`name`value!(`submit;x;"Run");""]}each test from res;
    out:.h.htac[`div; enlist[`style]!enlist "height:60%;width:60%;border:1px solid black;overflow:auto;";].h.table res;
    if[count args;
        test:`$first "=" vs first args;
        out:.rpt.run1test[test] , .h.br , out
        ];
    :out

 };

.rpt.run1test:{[test]
    debugOrig:@[value;`.test.debug; 0b]; / orig debug val
    .test.debug:0b;
    t:run test;
    .test.debug:debugOrig;
    input:read0 test;
    actual:"\n" vs .Q.s t`actual;

    textareas:.h.htac[`label; enlist[`for]!enlist[`input];"Input: "],
        .h.htac[`textarea; `id`name`rows`cols`readonly!(`input;`input; count input; 2 + max count each input;`true); "\n" sv input],
        .h.htac[`label; enlist[`for]!enlist[`actual];" Actual: "],
        .h.htac[`textarea; `id`name`rows`cols`readonly!(`actual;`actual; count actual;2 + max count each actual;`true); "\n" sv actual];

    if[not t`pass; 
        expected:"\n" vs .Q.s t`expected;
        textareas,:.h.htac[`label; enlist[`for]!enlist[`expected];" Expected: "],
        .h.htac[`textarea; `id`name`rows`cols`readonly!(`expected;`expected; count expected;2 + max count each expected;`true); "\n" sv expected]
        ];
    
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

