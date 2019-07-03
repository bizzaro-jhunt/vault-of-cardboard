;(function (jQuery, exported, document, undefined) {
  exported.now = function () {
    var d = new Date();
    return d.getTime();
  };

  exported.time = function (ts) {
    var d = new Date();
    d.setTime(parseInt(ts) * 1000);
    return d;
  };

  exported.clean = function (s) {
    return (s || '').replace(/\xe2\x80\x94/g, '&mdash;')
                    .replace(/\xe2\x88\x92/g, '-');
  };

  exported.quotify = function (name, set, s) {
    s = s || '';
    while (s.match('"')) {
      s = s.replace('"', '&ldquo;').replace('"', '&rdquo;');
    }
    s = s.replace(/&/g, '&amp;').replace(/ *â/, '&lt;cite&gt;&amp;mdash;');
    if (s.match(';cite')) {
      s += '&lt;/cite&gt;';
    }
    return '/* '+name+' ('+set.code+') */'+"\n\n\"&lt;blockquote&gt;"+s+"&lt;/blockquote&gt;\"";
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

  exported.price = function (d) {
    return '$'+d.toFixed(2).split('').reverse().join('').match(/.{1,3}/g).join(',').split('').reverse().join('').replace(/,\./, '.');
  };

  jQuery.fn.serializeObject = function () {
    var o = {};
    this.find('input[type="hidden"], [name]:visible').each(function (_, e) {
      o[$(e).attr('name')] = $(e).val();
    });
    return o;
  };

  jQuery.fn.autofocus = function () {
    if (this.is(':visible')) {
      this.find('.autofocus:visible').first().focus();
    }
    return this;
  };
})(jQuery, window, document);
