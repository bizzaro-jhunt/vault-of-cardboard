function tokenize(s) {
  var keywords = {
    AND:   [['AND']],
    OR:    [['OR']],
    NOT:   [['NOT']],

    OWNED: [['QUALIFIER','OWN'],
            ['IDENTIFIER', '1+']],
    HAVE:  [['QUALIFIER','OWN'],
            ['IDENTIFIER', '1+']],
    NEED:  [['QUALIFIER','OWN'],
            ['IDENTIFIER', '0']],

    UNIQUE: [['QUALIFIER', 'UNIQUE'],
             ['IDENTIFIER', 'card']],

    REPRINT:   [['QUALIFIER', 'REPRINT'],
                ['IDENTIFIER', 'y']],
    RESERVED:  [['QUALIFIER', 'RESERVED'],
                ['IDENTIFIER', 'y']]
  };

  var aliases = {
    POWER:  'P',
    ATTACK: 'P',

    TOUGHNESS: 'T',
    DEFENSE:   'T'
  };

  var qualify = function (q) {
    q = q.toUpperCase();
    return aliases[q] || q;
  };

  var kw = [];
  for (var k in keywords) { kw.push(k); }
  var kre = new RegExp("^("+kw.join('|')+")\\b(?!:)", 'i');

  var tok = [];
parsing:
  while (s.length > 0) {
    if (s.match(/^\s+/)) {
      s = s.replace(/^\s+/, '');
      continue parsing;
    }

    switch (s[0]) {
    case '"':
    case '\'':
      /* quoted string */
      for (var i = 1; i < s.length; i++) {
        if (s[i] == s[0]) {
          /* FIXME: no escape quoting yet */
          tok.push(['STRING', s.substr(1, i-1)]);
          s = s.substr(i+1);
          continue parsing;
        }
      }
      throw 'unterminated quoted string';

    case '(':
    case ')':
        tok.push([s[0]]);
        s = s.substr(1);
        continue parsing;

    case '@':
      tok.push(['QUALIFIER', 'COLOR']);
      s = s.substr(1);
      continue parsing;

    case '+':
      tok.push(['QUALIFIER', 'ORACLE']);
      s = s.substr(1);
      continue parsing;

    case '=':
      tok.push(['QUALIFIER', 'RARITY']);
      s = s.substr(1);
      continue parsing;

    case '!':
      tok.push(['NOT']);
      s = s.substr(1);
      continue parsing;
    }

    var m = s.match(kre);
    if (m) {
      var toks = keywords[m[1].toUpperCase()];
      for (var i = 0; i < toks.length; i++) {
        tok.push(toks[i]);
      }
      s = s.replace(kre, '');
      continue parsing;
    }

    var re = new RegExp('^([a-zA-Z0-9_-]+):\\s*');
    var m = s.match(re);
    if (m) {
      s = s.replace(re, '');
      tok.push(['QUALIFIER', qualify(m[1])]);
      continue parsing;
    }

    re = new RegExp('^([^\\s()]+)\\s*');
    m = s.match(re);
    if (m) {
      s = s.replace(re, '');
      tok.push(['IDENTIFIER', m[1]]);
      continue parsing;
    }

    throw 'unrecognized query fragment: ['+s.substr(0,50)+'...]';
  }

  /* collapse adjacent IDENTIFIER tokens */
  var collapsed = [],
      last = tok[0];;
  for (var i = 1; i < tok.length; i++) {
    if (last[0] == 'IDENTIFIER' && tok[i][0] == last[0]) {
      last[1] += ' ' + tok[i][1];
    } else {
      collapsed.push(last);
      last = tok[i];
    }
  }
  collapsed.push(last);
  return collapsed;
}

function Query(t,a,b,up) {
  this.type = t;
  this.a = a;
  this.b = b;
  this.up = up;
  this.unique = {};
}

Query.prototype.parent = function() {
  return this.up ? this.up.parent() : this;
};

function parse(tok) {
  var strict_re = function (v) { return new RegExp('\\b'+v+'\\b'); },
      loose_re  = function (v) { return new RegExp('\\b'+v+'\\b', 'i'); },
      setcode   = function (v) { return v.toUpperCase(); },
      literal   = function (v) { return v ; },
      legalese  = function (v) {
        v = v.toLowerCase();
        if (v == 'edh') {
          v = 'commander';
        }
        return v;
      },
      boolish   = function (v) {
        var fn = function (v) { return !v; }
        fn.string = 'no';
        switch (v.toLowerCase()) {
        case 'y':
        case 'yes':
        case '1':   fn = function (v) { return !!v; };
                    fn.string = 'yes';
        }
        return fn;
      },
      colorish  = function (v) {
        v = v.toUpperCase();

        var ck = function (w,u,b,r,g) {
          var fn = function (c) {
            var map = {};
            for (var i = 0; i < c.length; i++) { map[c[i]] = true; }
            return !!map.W == !!w &&
                   !!map.U == !!u &&
                   !!map.B == !!b &&
                   !!map.R == !!r &&
                   !!map.G == !!g;
          };
          fn.string = v;
          return fn;
        };

        switch (v) {
        case "NONE":     /* '' */  return ck(0, 0, 0, 0, 0);

        case "WHITE":    /* W */   return ck(1, 0, 0, 0, 0);
        case "BLUE":     /* U */   return ck(0, 1, 0, 0, 0);
        case "BLACK":    /* B */   return ck(0, 0, 1, 0, 0);
        case "RED":      /* R */   return ck(0, 0, 0, 1, 0);
        case "GREEN":    /* G */   return ck(0, 0, 0, 0, 1);

        case "AZORIUS":  /* WU */  return ck(1, 1, 0, 0, 0);
        case "DIMIR":    /* UB */  return ck(0, 1, 1, 0, 0);
        case "RAKDOS":   /* BR */  return ck(0, 0, 1, 1, 0);
        case "GRUUL":    /* RG */  return ck(0, 0, 0, 1, 1);
        case "SELESNYA": /* WG */  return ck(1, 0, 0, 0, 1);
        case "ORZHOV":   /* WB */  return ck(1, 0, 1, 0, 0);
        case "IZZET":    /* UR */  return ck(0, 1, 0, 1, 0);
        case "GOLGARI":  /* BG */  return ck(0, 0, 1, 0, 1);
        case "BOROS":    /* WR */  return ck(1, 0, 0, 1, 0);
        case "SIMIC":    /* UG */  return ck(0, 1, 0, 0, 1);

        case "BANT":     /* WUG */ return ck(1, 1, 0, 0, 1);
        case "ESPER":    /* WUB */ return ck(1, 1, 1, 0, 0);
        case "GRIXIS":   /* UBR */ return ck(0, 1, 1, 1, 0);
        case "JUND":     /* BRG */ return ck(0, 0, 1, 1, 1);
        case "NAYA":     /* WRG */ return ck(1, 0, 0, 1, 1);

        case "ABZAN":    /* WBG */ return ck(1, 0, 1, 0, 1);
        case "JESKAI":   /* WUR */ return ck(1, 1, 0, 1, 0);
        case "SULTAI":   /* UBG */ return ck(0, 1, 1, 0, 1);
        case "MARDU":    /* WBR */ return ck(1, 0, 1, 1, 0);
        case "TEMUR":    /* URG */ return ck(0, 1, 0, 1, 1);
        }

        var fn = function (c) {
          for (var i = 0; i < v.length; i++) {
            if (c.indexOf(v[i]) < 0) { return false; }
          }
          return true;
        };
        fn.string = v;
        return fn;
      },
      deckish   = function (v) {
        v = v.toLowerCase();
        var fn = function (decks) {
          return decks && decks[v];
        };
        fn.string = v;
        return fn;
      },
      range     = function (v) {
        var n, op, fn = function () { return false; };
        var m = v.match('^([<>]?=?)?([0-9]+(\\.[0-9]+)?)$');
        if (m) {
          op = m[1] || '=';
          n = parseFloat(m[2]);
        } else {
          m = v.match('^([0-9]+(\\.[0-9]+)?)\\+$');
          if (m) {
            op = '>=';
            n = parseFloat(m[1]);
          }
        }

        switch (op) {
        case '>':  fn = function (v) { return v >  n; }; break;
        case '<':  fn = function (v) { return v <  n; }; break;
        case '>=': fn = function (v) { return v >= n; }; break;
        case '<=': fn = function (v) { return v <= n; }; break;
        case '=':  fn = function (v) { return v == n; }; break;
        }
        fn.string = v;
        return fn;
      },
      uniquify  = function (v) {
        if (!('_uniques' in window)) { uniques = {card: {}, art: {}}; }
        v = v.toLowerCase();
        var fn = function (unique) {
          var k;
          switch (v) {
          case 'card': k = this.oid; break;
          case 'art':  k = this.art; break;
          }
          rc = !(k in unique);
          unique[k] = 1;
          return rc;
        };
        fn.string = v;
        return fn;
      },
      data      = [],
      ops       = [],
      prec      = {
        'AND': 1,
        'OR':  1,
        'NOT': 2
      };

  while (tok.length > 0) {
    var t = tok.shift();
    switch (t[0]) {
    case 'IDENTIFIER':
      data.push(new Query('NAME', new RegExp('\\b'+t[1]+'\\b', 'i')));
      break;

    case 'STRING':
      data.push(new Query('NAME', new RegExp('\\b'+t[1]+'\\b')));
      break;

    case 'QUALIFIER':
      var v = tok.shift();

      /* handle predictes that don't _need_ a value... */
      switch (t[1]) {
        case 'ACTIVATE':
        case 'DISCARD':
        case 'EXILE':
        case 'SACRIFICE':
        case 'TAP':
        case 'UNTAP':
          if (v) {
            switch (v[0]) {
            case 'IDENTIFIER':
            case 'STRING': break;
            default:
              tok.unshift(v);
              v = undefined;
              break;
            }
          }
          if (!v) {
            v = ['IDENTIFIER', ''];
          }
      }

      var fn;
      switch (v[0]) {
      case 'IDENTIFIER': fn = loose_re;  break;
      case 'STRING':     fn = strict_re; break;
      default:
        throw 'bad value for '+t[1]+' qualifier';
      }
      switch (t[1]) {
      case 'UNIQUE':  fn = uniquify; break;
      case 'SET':     fn = setcode;  break;
      case 'LAYOUT':
      case 'PT':
      case 'RARITY':  fn = literal;  break;
      case 'LEGAL':   fn = legalese; break;
      case 'SPOTLIGHT':
      case 'RESERVED':
      case 'REPRINT': fn = boolish;  break;
      case 'COLOR':   fn = colorish; break;
      case 'IN':      fn = deckish;  break;
      case 'EQUIP':
      case 'OWN':
      case 'USD':
      case 'P':
      case 'T':
      case 'CPT':
      case 'PTR':
      case 'CMC':     fn = range;    break;
      }
      data.push(new Query(t[1], fn(v[1])));
      break;

    case 'AND':
    case 'OR':
    case 'NOT':
      var z = ops.length - 1;
      while (z >= 0 && ops[z] != '(' && prec[ops[z]] >= prec[t[0]]) {
        var op = ops.pop(); z--;
        switch (op) {
        case 'NOT':
          if (data.length < 1) { throw 'stack underflow (data) for '+op+' op'; }
          data.push(new Query(op, data.pop()));
          break;

        case 'OR':
        case 'AND':
          if (data.length < 2) { throw 'stack underflow (data) for '+op+' op'; }
            var b = data.pop();
            var a = data.pop();
            data.push(new Query(op, a, b));
            break;
        }
      }
      ops.push(t[0]);
      break;

    case '(':
      ops.push(t[0]);
      break;

    case ')':
      var z = ops.length - 1;
      while (z >= 0 && ops[z] != '(') {
        /* ---->8--------------- */
        var op = ops.pop(); z--;
        switch (op) {
        case 'NOT':
          if (data.length < 1) { throw 'stack underflow (data) for '+op+' op'; }
          data.push(new Query(op, data.pop()));
          break;

        case 'OR':
        case 'AND':
          if (data.length < 2) { throw 'stack underflow (data) for '+op+' op'; }
            var b = data.pop();
            var a = data.pop();
            data.push(new Query(op, a, b));
            break;
        }
        /* ---->8--------------- */
      }
      if (z < 0) { throw 'mismatched parentheses'; }
      ops.pop();
      break;

    default:
      console.log('no handler for a '+t[0]+' yet...');
    }
  }

  while (ops.length > 0) {
    var op = ops.pop();
    switch (op) {
    case 'NOT':
      if (data.length < 1) { throw 'stack underflow (data) for '+op+' op'; }
      data.push(new Query(op, data.pop()));
      break;

    case 'OR':
    case 'AND':
      if (data.length < 2) { throw 'stack underflow (data) for '+op+' op'; }
      var b = data.pop();
      var a = data.pop();
      data.push(new Query(op, a, b));
      break;

    case '(':
    case ')':
      throw 'mismatched parentheses';
    }
  }
  if (data.length != 1) {
    throw 'syntax error';
  }
  return data[0];
}

Query.parse = function (s) {
  return parse(tokenize(s));
}

Query.prototype.toString = function () {
  switch (this.type) {
  case 'UNIQUE':
  case 'SET':
  case 'TYPE':
  case 'NAME':
  case 'ORACLE':
  case 'FLAVOR':
  case 'ACTIVATE':
  case 'DISCARD':
  case 'EXILE':
  case 'SACRIFICE':
  case 'TAP':
  case 'UNTAP':
  case 'ARTIST':
  case 'RARITY':
  case 'LAYOUT':
  case 'LEGAL':
  case 'PT':
  case 'IN':
    return '('+this.type+' '+this.a.toString()+')';

  case 'SPOTLIGHT':
  case 'RESERVED':
  case 'REPRINT':
  case 'COLOR':
    return '('+this.type+' '+this.a.string+')';

  case 'EQUIP':
  case 'OWN':
  case 'USD':
  case 'CMC':
  case 'P':
  case 'T':
  case 'CPT':
  case 'PTR':
    return '('+this.type+' '+this.a.string+')';

  case 'NOT':
      return '(!'+this.a.toString()+')';

  case 'AND':
  case 'OR':
      return '('+this.type+' '+this.a.toString()+' '+this.b.toString()+')';
  }
}

Query.prototype.match = function (card) {
  switch (this.type) {
  case 'UNIQUE':
    return this.a.call(card, this.parent().unique);
  case 'SET':
    return this.a == card.set.code;
  case 'TYPE':
    card.type.replace(/—/g, '-'); /* FIXME: normalize lookalike chars */
    return this.a.exec(card.type);
  case 'NAME':
    return this.a.exec(card.name);
  case 'ORACLE':
    return this.a.exec(card.oracle);
  case 'FLAVOR':
    return this.a.exec(card.flavor);
  case 'ARTIST':
    return this.a.exec(card.artist);
  case 'RARITY':
    return this.a == card.rarity;
  case 'COLOR':
    return this.a.call(card, card.color);
  case 'P':
      return card.power != "" && this.a.call(card, card.power);
  case 'T':
      return card.power != "" && this.a.call(card, card.toughness);
  case 'CPT':
      return card.power != "" && this.a.call(card, parseInt(card.power) + parseInt(card.toughness));
  case 'IN':
      return this.a.call(card, card.decks);
  case 'PTR':
      return card.power != "" && this.a.call(card, parseInt(card.power) * 1.0 / parseInt(card.toughness));
  case 'LAYOUT':
      return this.a == card.layout;
  case 'LEGAL':
      return card.legal[this.a.toLowerCase()] == 'legal';
  case 'PT':
      return this.a == card.pt;
  case 'SPOTLIGHT':
      return this.a.call(card, card.spotlight);
  case 'RESERVED':
      return this.a.call(card, card.reserved);
  case 'REPRINT':
      return this.a.call(card, card.reprint);
  case 'OWN':
    return this.a.call(card, card.owned);
  case 'USD':
    return this.a.call(card, card.price);
  case 'CMC':
    return this.a.call(card, card.cmc);

  case 'EQUIP':
    var m = card.oracle.match(/\bequip {(\d+)}/i);
    if (!m) { return false; }
    return this.a.call(card, parseInt(m[1]));

  case 'ACTIVATE':
    var l = card.oracle.split(/\n+/);
    for (var i = 0; i < l.length; i++) {
      l[i] = l[i].replace(/ *\(.*$/, '');
      var m = l[i].match(/: (.*)/);
      if (m && this.a.exec(m[1])) { return true; }
    }
    return false;

  case 'DISCARD':
    var l = card.oracle.split(/\n+/);
    for (var i = 0; i < l.length; i++) {
      l[i] = l[i].replace(/ *\(.*$/, '');
      var m = l[i].match(/\bdiscard\b.*?: (.*)/i);
      if (m && this.a.exec(m[1])) { return true; }
    }
    return false;

  case 'EXILE':
    var l = card.oracle.split(/\n+/);
    for (var i = 0; i < l.length; i++) {
      l[i] = l[i].replace(/ *\(.*$/, '');
      var m = l[i].match(/\bexile\b.*?: (.*)/i);
      if (m && this.a.exec(m[1])) { return true; }
    }
    return false;

  case 'SACRIFICE':
    var l = card.oracle.split(/\n+/);
    for (var i = 0; i < l.length; i++) {
      l[i] = l[i].replace(/ *\(.*$/, '');
      var m = l[i].match(/\bsacrifice\b.*?: (.*)/i);
      if (m && this.a.exec(m[1])) { return true; }
    }
    return false;

  case 'TAP':
    var l = card.oracle.split(/\n+/);
    for (var i = 0; i < l.length; i++) {
      l[i] = l[i].replace(/ *\(.*$/, '');
      var m = l[i].match(/[^:]*{T}.*?: (.*)/);
      if (m && this.a.exec(m[1])) { return true; }
    }
    return false;

  case 'UNTAP':
    var l = card.oracle.split(/\n+/);
    for (var i = 0; i < l.length; i++) {
      l[i] = l[i].replace(/ *\(.*$/, '');
      var m = l[i].match(/[^:]*{Q}.*?: (.*)/);
      if (m && this.a.exec(m[1])) { return true; }
    }
    return false;

  case 'NOT':
    return !this.a.match(card);
  case 'AND':
    return this.a.match(card) && this.b.match(card);
  case 'OR':
    return this.a.match(card) || this.b.match(card);
  }
}
