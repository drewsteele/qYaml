.yml.trim:{ 
    m:min{first where not" "=x}each (c:x?\:"#")#'x;
    :@[x;where c>m;m _]; / 
    };

.yml.stripComments:{[yml]
    :rtrim each {x where 0<count each x} (yml?\:"#")#'yml;
    };

/ TODO - handle headers of docs
.yml.splitDocs:{[yml]
    if[not yml[0] like "---*"; yml:(enlist"---"),yml]; / add in proper header
    d:cut[;yml] where yml like\:"---*";
    :{#[;x]x?"..."}each d;
    };

.yml.load:{[yml]
    if[-11h=type yml; 
        yml:@[read0; yml; {[x;e]'"failed to read yaml file ",string[x],": ",e}[yml;]];
    ];
    docs:.yml.splitDocs yml;
    res:.yml.parse each docs;
    res:res where not (::)~'res;
    :$[1=count res; first res; res];
    };

.yml.parsers:(!) . flip (
    ("|"    ; `.yml.parseLiteral);
    (">"    ; `.yml.parseFoldedScalar);
    ("{"    ; `.yml.parseFlow);
    ("["    ; `.yml.parseFlow)
  );

.yml.parseLiteral:{("\n" sv .yml.trim 1_x),"\n"};
.yml.parseFoldedScalar:{
    s:.yml.trim 1_x;
    ni:-1_next i1:" "=/:s[;0];i:-1_i1; / indentation index but ignore the last line - we handle it at the end
    / fold a line with a space where it and the next line are not indented
    s:@[s;where not[i]and not ni;{x," "}];     
    s:@[s;where i; "\n",]; / fold a newline on indentation
    s:@[s;where i&not ni; {x,"\n"}]; / fold a newline where it gets unappended
    :raze s,"\n"; / add newline at the end
    };

    
.yml.parseFlow:{[s]
    d:first r:rtrim raze over s;
    if[not last[r]=c:"}]""{["?d; '"missing closing delim - expected ",c];
    g:sums 1 1 -1 -1"[{}]"?r1:",",1_-1_r;
    p:trim each 1_/:cut[;r1]where (0=g)&","=r1;
    / if it was a list give it proper list notation for parsing in standard way 
    if[d~"["; p:"- ",/:p]; 
    :.yml.parse p
    };

.yml.parse:{[s]

    if[10h=type s; :.yml.parseSimple s]; 

    if[s[0] like "---*";
        s:{$[0=count x 0;1_x;x]}@[s;0;trim@3_]
        ];

    f:first/[s];
    if[f in key .yml.parsers; :.yml.parsers[f] s];


    s:.yml.trim s;
    if[any "- "~/:s[;0 1];
        :.yml.parseList s;
        ];

    tl:where not s[;0]in " ]}";
    if[all not null kv:first each ss[;": "]each (s@tl),\:" "; / its a dict
        kys:`$#'[kv;s@tl];
        vals:.yml.parse each tl cut @[s;tl;{y _ x};2+kv];
        :kys ! vals
        ];
    
    :@[.yml.parseSimple; s; {'"failed to parse yml - ",x}]
    
 };

.yml.parseFlowScalar:{[s]
    :trim " " sv s;
    };

.yml.parseList:{[s]
    s:.yml.stripComments s;
    li:where "- "~/:s[;0 1];
    :.yml.parse each li cut 2_/:s;
    };

/ more cases needed here
.yml.parseSimple:{[s]
    if[0=type s; s:" "sv trim each s]; / if it is a list, fold it
    s:(s?"#")#s;
    if[.yml.safeToValue s;
        :@[value; s; s]
        ];
    / TODO - handle nulls/booleans
    :trim s
    };

.yml.safeToValue:{[s]
    :any 
      (all trim[s] in .Q.n,".";
       all"\""~'(first;last)@\:s);
  };
