;(function (exported, document, undefined) {
  exported.clean = function (s) {
    return s.replace(/\xe2\x80\x94/g, '&mdash;')
            .replace(/\xe2\x88\x92/g, '-');
  };

  exported.symbolize = function (s) {
    return s.replace(/{(.+?)}/g, function (m, found, offset, s) {
      found = found.toLowerCase().split('/');
      var classes = [];
      for (var i = 0; i < found.length; i++) {
        switch (found[i]) {
        default:    classes.push('ms-'+found[i]); break;
        case 't':   classes.push('ms-tap');       break;
        case 'q':   classes.push('ms-untap');     break;
        }
      }
      return '<i class="ms ms-cost '+classes.join(' ')+'"></i>';
    });
  };
})(window, document);
