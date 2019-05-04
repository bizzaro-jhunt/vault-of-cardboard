;(function (exported, document, undefined) {
  const SET_ATTRIBUTE    = 1,
        REMOVE_ATTRIBUTE = 2,
        SET_PROPERTY     = 3,
        REMOVE_PROPERTY  = 4,
        REPLACE_NODE     = 5,
        APPEND_CHILD     = 6,
        REMOVE_CHILD     = 7,
        REPLACE_TEXT     = 8;

  /* diff the ATTRIBUTES of two nodes, and return a
     (potentially empty) patch op list. */
  var diffa = function (a, b) {
    const ops = [];
    const { attributes: _a } = a;
    const { attributes: _b } = b;

    /* if the attribute is only defined in (a), then
       it has been removed in (b) and should be patched
       as a REMOVE_ATTRIBUTE.  */
    for (let attr in _a) {
      if (!(attr in _b)) {
        ops.push({
          op:    REMOVE_ATTRIBUTE,
          node:  a,
          key:   _a[attr].nodeName
        });
      }
    }

    /* if the attribute is only defined in (b), or is
       defined in both with different values, patch as
       a SET_ATTRIBUTE to get the correct value. */
    for (let attr in _b) {
      if (!(attr in _a) || _a[attr] !== _b[attr]) {
        ops.push({
          op:    SET_ATTRIBUTE,
          node:  a,
          key:   attr,
          value: _b[attr]
        });
      }
    }

    return ops;
  };

  /* diff the event handlers; NOT CURRENTLY IMPLEMENTED. */
  var diffev = function (a, b) {
    return [];
  };

  /* diff the PROPERTIES  of two nodes, and return a
     (potentially empty) patch op list. */
  var diffp = function (a, b) {
    return []; /* FIXME what is a property? */
    const ops = [];
    const { properties: _a } = a;
    const { properties: _b } = b;

    /* if the property is only defined in (a), then
       it has been removed in (b) and should be patched
       as a REMOVE_PROPERTY.  */
    for (let prop in _a) {
      if (!(prop in _b)) {
        ops.push({
          op:    REMOVE_PROPERTY,
          node:  a,
          key:   prop
        });
      }
    }

    /* if the property is only defined in (b), or is
       defined in both with different values, patch as
       a SET_PROPERTY to get the correct value. */
    for (let prop in _b) {
      if (!(prop in _a) || _a[prop] !== _b[prop]) {
        ops.push({
          op:    SET_PROPERTY,
          node:  a,
          key:   prop,
          value: _b[prop]
        });
      }
    }

    return ops;
  };

  var diffe = function (a, b) {
    if (a.localName === b.localName) {
      return []
             .concat(diffa(a, b))
             .concat(diffev(a, b))
             .concat(diffp(a, b))
    }
  };

  var difft = function (a, b) {
    if (a.textContent === b.textContent) {
      return [];
    }
    return [{
      op:   REPLACE_TEXT,
      node: a,
      with: b.textContent
    }];
  };

  /* diff two NODEs, without recursing through child nodes */
  var diffn1 = function (a, b) {
    if (a.nodeType != b.nodeType) {
      /* nothing in common */
      return null;
    }

    if (a.nodeType == Node.ELEMENT_NODE) {
      return diffe(a, b);
    }
    if (a.nodeType == Node.TEXT_NODE) {
      return difft(a, b);
    }

    console.log('unrecognized a type %s', a.nodeType);
    return null;
  };

  /* diff two NODEs, co-recursively with diff() */
  var diffn = function (a, b) {
    let ops = diffn1(a, b);

    if (ops) {
      return ops.concat(diff(a, b));
    }

    return [{
      op:   REPLACE_NODE,
      node: a,
      with: b
    }];
  };

  exported.diff = function (a, b) {
    let ops = [];
    const { childNodes: _a } = a;
    const { childNodes: _b } = b;

    const _al = _a ? _a.length : 0;
    const _bl = _b ? _b.length : 0;

    for (let i = 0; i < _bl; i++) {
      if (!_a[i]) {
        ops.push({
          op:    APPEND_CHILD,
          node:  a,
          child: _b[i]
        });
        continue;
      }

      ops = ops.concat(diffn(_a[i], _b[i]));
    }

    for (var i = _bl; i < _al; i++) {
      ops.push({
        op:    REMOVE_CHILD,
        node:  a,
        child: _a[i]
      });
    }

    return ops;
  };




  exported.patch = function (e, ops) {
    for (let i = 0; i < ops.length; i++) {
      switch (ops[i].op) {
        case SET_ATTRIBUTE:    ops[i].node.attributes[ops[i].key] = ops[i].value;             break;
        case REMOVE_ATTRIBUTE: ops[i].node.removeAttribute(ops[i].key);                       break;
        case SET_PROPERTY:     /* FIXME needs implemented! */                                 break;
        case REMOVE_PROPERTY:  /* FIXME needs implemented! */                                 break;
        case REPLACE_NODE:     ops[i].node.parentNode.replaceChild(ops[i].with, ops[i].node); break;
        case APPEND_CHILD:     ops[i].node.appendChild(ops[i].child);                         break;
        case REMOVE_CHILD:     ops[i].node.removeChild(ops[i].child);                         break;
        case REPLACE_TEXT:     ops[i].node.textContent = ops[i].with;                         break;
        default:
          console.log('unrecognized patch op %d for ', ops[i].op, op);
          break;
      }
    }
  };
})(window, document);
