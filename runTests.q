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
