.yml.trim:{ 
    m:min{first where not" "=x}each (c:x?\:"#")#'x;
    :@[x;where c>m;m _]; / 
    };

.yml.rmComment:{#[;x]x?"#"};
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

/ nulls booleans and infinities
.yml.nbi:(!) . flip (
    (""     ; (::));
    ("null" ; (::));
    ("true" ; 1b);
    ("false"; 0b);
    (".nan" ; 0n);
    (".inf" ; 0w);
    ("+.inf"; 0w);
    ("-.inf"; -0w)
    );
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

    tl:where not (s[;0]in " ]}")or trim[s] like "#*";
    if[count[tl]&all not null kv:first each ss[;": "]each (s@tl),\:" "; / its a dict
        kys:`$#'[kv;s@tl];
        vals:.yml.parse each tl cut @[s;tl;{y _ x};2+kv];
        :kys ! vals
        ];
    
    :@[.yml.parseSimple; s; {'"failed to parse yml - ",x}]
    
 };

.yml.parseList:{[s]
    s:rtrim each {x where 0<count each x} .yml.rmComment each s;
    li:where "- "~/:s[;0 1];
    :.yml.parse each li cut 2_/:s;
    };

/ more cases needed here
.yml.parseSimple:{[s]
    if[0=type s; s:trim " "sv trim each s]; / if it is a list, fold it
    s1:trim .yml.rmComment s; / for use once we have checked it is not a string literal with a '#'
    ls:lower s;
    :$[
        "\""=first s             ; .yml.parseDoubleQuote s;
        "'"=first s              ; .yml.parseSingleQuote s;
        all trim[s1] in .Q.n,"." ; @[value; s1; s1];
        s1 like "0x*"            ; 16 sv "0123456789abcdef"?/:2_lower s1;
        (s1 like "0o*")          ; 8 sv 10 vs "J"$2_s1;
        ls in key .yml.nbi       ; .yml.nbi ls;
        s / default - return as is
        ];
    };

.yml.parseDoubleQuote:{[s]
    d:1+ss[s;"\""] except 1+ss[s;"\\\""]; / ignore escaped double quotes
    if[(2<>count d) or 0<count trim .yml.rmComment last[d]_s;
        '"Failed to parse yaml - incorrect double quote usage: ",s]; 
    / try to .j.k to resolve some escape sequences that json handles
    :@[.j.k; ssr[last[d]#s; "#";"\\#"]; last[d]#s]; 
    };
.yml.parseSingleQuote:{[s]
    d:1+ss[s;"'"] except raze ss[s;"''"]+\:0 1; / ignore escaped single quotes
    if[(2<>count d) or 0<count trim .yml.rmComment last[d]_s; 
        '"Failed to parse yaml - incorrect single quote usage: ",s];
    :ssr[1_-1_last[d]#s; "''";"'"]
    };
