/ use global variable for anchors 
/ would be nice to do this in a more functional way without globals but this was easiest
.yml.anchors:(enlist`)!enlist (::); 

.yml.trim:{ 
    m:min{first where not" "=x}each (c:x?\:"#")#'x;
    :@[x;where c>m;m _]; / 
    };

.yml.rmComment:{#[;x]x?"#"};

.yml.splitDocs:{[yml]
    sep:where yml like\:"---*";
    if[0=count sep; :enlist yml];
    d:sep cut yml;
    :{#[;x]x?"..."}each d;
    };

.yml.load:{[yml]
    if[-11h=type yml; 
        yml:@[read0; yml; {[x;e]'"failed to read yaml file ",string[x],": ",e}[yml;]];
    ];
    .yml.anchors:(enlist`)!enlist (::); / reset global anchors
    docs:.yml.splitDocs yml;
    res:.yml.parse each docs;
    res:res where not (::)~'res;
    :$[1=count res; first res; res];
    };

.yml.parse:{[s]

    if[10h=type s; :.yml.parseSimple s]; 

    if[s[0] like "---*";
        s:{$[0=count x 0;1_x;x]}@[s;0;trim@3_]
        ];

    s:_[;s]first where not trim[s] like "#*"; / drop any comments at the top of the stream

    f:first/[s];
    if[f in key .yml.parsers; :.yml.parsers[f] s];


    s:.yml.trim s;
    if[any "- "~/:s[;0 1];
        :.yml.parseList s;
        ];

    if[.yml.isDict s; 
        :.yml.parseDict s
        ];
    
    :@[.yml.parseSimple; s; {'"failed to parse yml - ",x}]
    
 };
.yml.parsers:(!) . flip (
    ("!"    ; `.yml.parseTag);
    ("|"    ; `.yml.parseLiteral);
    (">"    ; `.yml.parseFoldedScalar);
    ("&"    ; `.yml.parseAnchor);
    ("*"    ; `.yml.parseAlias);
    ("{"    ; `.yml.parseFlow);
    ("["    ; `.yml.parseFlow)
  );
  
 
.yml.parseTag:{[s]
    if[10h=type s; s:enlist s];
    tag:`$2_first " " vs s[0]; val:@[s;0; (3+count string tag)_];
    if[tag=`str; 
        :trim " " sv trim each val
        ];
    if[tag=`omap;
        if[not res~distinct res:.yml.parse val; '"duplicate value found in omap - should be unique list of maps"];
        :res
        ];
    if[tag=`set;
        res:.yml.parse val;
        if[not 99h=type res; '"invalid format for set type - should be a map with null values"];
        :.yml.parseSimple each string distinct key res / convert back to native types for a set
        ];

     :.yml.parse val;
   };

.yml.parseLiteral:{[s]
    if[10h=type s; s:enlist s];
    endWith:"\n"; / default to end with a newline
    origNewLines:1|count[s] - 1+last where not ""~/:trim each s;
    if["|"=first/[s]; s:@[s;0;1_]]; / remove the literal indicator
    if["-"=first/[s]; s:@[s;0;1_]; endWith:""]; / - sign means strip newline at end
    if["+"=first/[s]; s:@[s;0;1_]; endWith:origNewLines#"\n"]; / + sign means keep oringal new lines
    if[0=count trim s[0]; s:1_s]; / drop empty first line
    tl:first l:{first where  " "<>x}each s;
    if[not all {(x~"") or x like "#*"} each s where not l=tl;
        '"invalid nesting level for literal string ",.Q.s s
        ];
    :("\n" sv .yml.trim s@where tl=l),endWith;
    };
.yml.parseFoldedScalar:{[s]
    if[10h=type s; s:enlist s];
    endWith:"\n"; / default to end with a newline
    origNewLines:1|count[s] - 1+last where not ""~/:trim each s;
    if[">"=first/[s]; s:@[s;0;1_]]; / remove the flow indicator
    if["-"=first/[s]; s:@[s;0;1_]; endWith:""]; / - sign means strip newline at end
    if["+"=first/[s]; s:@[s;0;1_]; endWith:origNewLines#"\n"]; / + sign means keep oringal new lines
    if[0=count trim s[0]; s:.yml.trim 1_s]; / drop empty first line
    ni:-1_next i1:" "=/:s[;0];i:-1_i1; / indentation index but ignore the last line - we handle it at the end
    / fold a line with a space where it and the next line are not indented
    s:@[s;where not[i]and not ni;{x," "}];     
    s:@[s;where i; "\n",]; / fold a newline on indentation
    s:@[s;where i&not ni; {x,"\n"}]; / fold a newline where it gets unappended
    :raze s,endWith; / add newline at the end
    };

.yml.parseAnchor:{[s]
    if[10h=type s; s:enlist s];
    anchor:`$1_first " " vs s[0];
    val:.yml.parse @[s;0;(2+count string anchor)_];
    .yml.anchors:.yml.anchors,enlist[anchor]!enlist val;
    :val;
    };

.yml.parseAlias:{[s]
    alias:`$1_s:trim .yml.rmComment " " sv s;
    if[not alias in key .yml.anchors; '"no matching anchor found for alias ",string[alias]];
    :.yml.anchors alias
    };
    
.yml.parseFlow:{[s]
    d:first r:rtrim raze over s;
    if[not d in "{["; '"invalid opening delim for map or seq - should start with { or ["];
    if[not last[r]=c:"}]""{["?d; '"missing closing delim - expected ",c];
    g:sums 1 1 -1 -1"[{}]"?r1:",",1_-1_r;
    p:trim each 1_/:cut[;r1]where (0=g)&","=r1;
    / if it was a list give it proper list notation for parsing in standard way 
    if[d~"["; p:"- ",/:p]; 
    / if it was a map ensure any missing keys are filled with nulls
    if[d~"{"; p:@[p; where not ":" in/:p; {x,":"}]];
    :.yml.parse p
    };

.yml.parseList:{[s]
    s:rtrim each {x where 0<count each x} .yml.rmComment each s;
    li:where "- "~/:s[;0 1];
    :.yml.parse each li cut 2_/:s;
    };

.yml.isDict:{[s]
    tl:where not (s[;0]in " ]}")or trim[s] like "#*"; / top level
    if[0=count tl; :0b];
    / each top level entry should be like "a: ..." or should be a complex mapping
    / i.e. ("? key"; ": value")
    :all {(0<first ss[x;": "])or x[0] in "?:"}each (s@tl),\:" ";
    };

.yml.parseDict:{[s]
    tl:where not (s[;0]in " ]}")or trim[s] like "#*";
    stl:s@tl; / top level entiries in the yaml doc, i.e. should be the dict keys
    lvls:tl + til each(count[s]^next tl)-tl; / split nested levels

    res:()!();

    mkl:where 0<mks:first each ss[;": "]each stl,\:" "; / normal mapping levels i.e. "a: ..."
    mk:();
    if[count mkl;
        mk:`$#'[mks@mkl; stl@mkl]; / normal mapping keys
        mv:.yml.parse each @[s; tl@mkl; {y _ x}; 2+mks@mkl]@/:lvls@mkl;
        res:res,mk!mv;
        ];

    ckl:where stl[;0]="?"; / complex mappings i.e. "? a ..."
    ck:();
    if[count ckl; / complex keys
        ck:`$.yml.parse each trim each @[s;tl@ckl;2_]@/:lvls@ckl;
        ck:@[ck; where 1<count each ck; {`$"," sv string x}]; / join complex keys with comma rather than proper compound key
        cvl:where stl[;0]=":";
        cv:.yml.parse each trim each @[s;tl@cvl;2_]@/:lvls@cvl;
        valExists:(1+ckl) in cvl; / complex value is set explicitly, if not it should be null
        res:res,((ck where valExists)!cv) , (ck where not valExists)!(count where not valExists)#enlist (::); 
        ];

    :((mk,ck)@iasc[mkl,ckl])#res; / ensure it is ordered correctly
    };

/ parsing for atomic values, handles
/ single quotes, double quotes, numbers, timestamps, hex, octal, nulls/booleans/inf and standard strings
.yml.parseSimple:{[s]
    if[0=type s; s:trim " "sv trim each s]; / if it is a list, fold it
    s1:trim .yml.rmComment s; / for use once we have checked it is not a string literal with a '#'
    ls:lower s1;
    :$[
        "\""=first s             ; .yml.parseDoubleQuote s;
        "'"=first s              ; .yml.parseSingleQuote s;
        .yml.isNumber s1         ; @[value; s1; s1];
        .yml.isTs s1             ; @[.yml.parseTs; s1; s1]; / default to input string if parsing fails
        s1 like "0x*"            ; 16 sv "0123456789abcdef"?/:2_lower s1;
        (s1 like "0o*")          ; 8 sv 10 vs "J"$2_s1;
        ls in key .yml.nbi       ; .yml.nbi ls;
        s1 / default - return without comments
        ];
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

/ it starts with a number as has valid number components (decimals or e notation)
.yml.isNumber:{(x[0]in .Q.n)& all x in .Q.n,".e+"}

/ allow iso or kdb date formats, e.g. 2001.01.01 or 2001-01-01
.yml.isTs:{x like "[1-9][0-9][0-9][0-9][.-][0-3][0-9][.-][0-3][0-9]*"};
.yml.parseTs:{
    if[not lower[x 10]in"td "; '"invalid ts type"];
    ts:trim @[x," ";10; :; "D"]; / convert to kdb timestamp format
    ts:$[2 = count tss:"+" vs 11_ts;
          ("D"$10#ts)+("N"$tss[0])-"U"$tss[1]; / +n means it is n hours ahead of GMT so subtract to convert to GMT
        2 = count tss:"-" vs 11_ts;
          ("D"$10#ts)+("N"$tss[0])+"U"$tss[1]; / -n means it is n hours behind GMT so add to convert to GMT
        "Z" = last ts;
          "P"$-1_ts;
        "P"$ts
       ];
   if[any null ts; '"failed to parse timestamp"];
   :ts
   };


/ TODO - add .yml.dump for writing out yaml from kdb objects
.yml.spaces:2;
.yml.dump:{[x]
    :$[10h~type x; enlist; (::)].yml.write[x;0];
    };

.yml.sc:"'\\\"\n\t",.Q.n; / if a string contains any of these characters then escape it in single quotes
.yml.write:{[x;lvl]
    s:(.yml.spaces*lvl)#" ";
    out:$[
      98h=type x; / table as list of dictionaries
        raze enlist["- "],/:.yml.write[;lvl+1] each x;
      99h=type x;
        raze .yml.writeKv[;;lvl]'[key x; value x];
      10h=type x; / escape single quotes, else leave as is for readability
        $[any x in .yml.sc; "'",ssr[x;"'";"''"],"'"; x];
      type[x] within 0 20h; 
        raze .yml.writeLi[;lvl]each x;
      type[x] in neg 19 12h;
        .h.iso8601 x;
      any nbi:x~/:value .yml.nbi;
        .yml.nbi?x;
      string x
      ];
    
     :$[10h=type out; out;s,/:out]; / nest to correct level
 
    };

.yml.writeKv:{[k;v;lvl]
    yk:$[10h=type k; k; string[k]],": ";
    / nested value so increase lvl by one and enlist the key so it sits on its own line
    if[nv:(type[v]>=0)&not 10h=type v; 
        lvl:lvl+1; 
        yk:enlist yk
        ];
    :$[not nv; enlist; (::)] yk , .yml.write[v; lvl];
    };

.yml.writeLi:{[li; lvl]
    sep:"- ";
    if[nv:(type[li]>=0)&not 10h=type li; 
        sep:enlist sep;
        lvl:lvl+1;
        ];
    :$[not nv; enlist; (::)] sep,.yml.write[li; lvl]
    };
