;(function (window, document, undefined) {
  var Clarifier = function () {
    this.e          = undefined;
    this.problems   = [];
    this.candidates = 0;
  };

  Clarifier.check = function (vif, options) {
    $.ajax({
      type: 'POST',
      url:  '/v/import/validate',

      contentType: 'application/json',
      data:        JSON.stringify({ vif: vif }),

      success: function (data) {
        if (data.vif && options.update) {
          options.update.apply({}, [data.vif]);
        }

        if (data.problems && data.problems.length > 0) {
          var clair = new Clarifier();
          for (var i = 0; i < data.problems.length; i++) {
            clair.add(data.problems[i]);
          }

          options.failed.apply({}, [clair, undefined]);

        } else if (data.error) {
          options.failed.apply({}, [undefined, data.error]);

        } else {
          options.ok.apply({}, []);
        }
      }
    });
  }

  Clarifier.prototype.interactive = function () {
    return this.candidates > 0;
  };

  Clarifier.prototype.add = function (data) {
    data.solutions = {};
    this.problems.push(data);
    this.candidates += data.candidates.length;
  };

  Clarifier.prototype.increment = function (prob, vif) {
    prob = parseInt(prob);
    if (!this.problems[prob]) {
      return;
    }
    if (!(vif in this.problems[prob].solutions)) {
      this.problems[prob].solutions[vif] = 1;
    } else {
      this.problems[prob].solutions[vif] += 1;
    }

    var $top = this.e.find('[data-problem="'+prob.toString()+'"] [data-vif="'+vif+'"]');
    $top.attr('data-n', this.problems[prob].solutions[vif]);
    $top.find('.band > span').html(this.problems[prob].solutions[vif]);
    this.redraw(prob);
  };

  Clarifier.prototype.decrement = function (prob, vif) {
    prob = parseInt(prob);
    if (vif in this.problems[prob].solutions) {
      var $top = this.e.find('[data-problem="'+prob.toString()+'"] [data-vif="'+vif+'"]');

      this.problems[prob].solutions[vif] -= 1;
      if (this.problems[prob].solutions[vif] <= 0) {
        delete this.problems[prob].solutions[vif];
        $top.removeAttr('data-n');
        $top.find('.band > span').html('0');
      } else {
        $top.attr('data-n', this.problems[prob].solutions[vif]);
        $top.find('.band > span').html(this.problems[prob].solutions[vif]);
      }
    }
    this.redraw(prob);
  };

  Clarifier.prototype.redraw = function (prob) {
    /* assemble a list of changes, that can be sorted by name/set */
    var changes = [];
    for (var vif in this.problems[prob].solutions) {
      changes.push({
        key:  vif,
        html: '<li><ins>'+this.problems[prob].solutions[vif]+'x '+vif+'</ins></li>'
      });
    }
    changes.sort(function (a,b) {
      return a.key > b.key ? 1 : -1;
    });

    var $changes = this.e.find('[data-problem='+prob+'] .changes').empty();
    if (changes.length == 0) {
      return;
    }
    $changes.append('<li><del>'+this.problems[prob].wanted.line+'</del></li>');
    for (var i = 0; i < changes.length; i++) {
      $changes.append(changes[i].html);
    }
  };

  Clarifier.prototype.patch = function (s) {
    var patch = [];
    for (var i = 0; i < this.problems.length; i++) {
                              console.log(JSON.stringify(this.problems[i]));
      var changes = [];
      for (var vif in this.problems[i].solutions) {
        changes.push({
          key:  vif,
          text: this.problems[i].solutions[vif]+'x '+vif
        });
      }
      if (changes.length == 0) {
        continue;
      }

      changes.sort(function (a,b) {
       return a.key > b.key ? 1 : -1;
      });
      console.log(changes);

      var p = {
        line:    this.problems[i].wanted.lineno,
        changes: [
          "",
          "##",
          "## modified during import, from:",
          "##",
          "## from:",
          "## "+this.problems[i].wanted.line,
          "##",
          "## to:",
        ]
      };
      for (var j = 0; j < changes.length; j++) {
        p.changes.push(changes[j].text);
      }
      p.changes.push("");
      patch.push(p);
    }

    var lines = s.split(/\n/);
    for (var i = 0; i < patch.length; i++) {
      lines.splice(patch[i].line - 1, 1, patch[i].changes.join(("\n")));
    }
    return lines.join("\n");
  };

  Clarifier.prototype.mount = function (parent) {
    this.e = $(parent).empty();

    $(parent).template('clarify', { problems: this.problems });
    if (!this.e.data('clarifier-ed')) {
      this.e.data('clarifier-ed', 'yes');
      this.e
        .on('click', '.band a', function (event) {
          event.preventDefault();
          var vif  = $(event.target).closest('[data-vif]').attr('data-vif');
          var rel  = $(event.target).closest('a[rel]').attr('rel');
          var c    = $(event.target).closest('[data-has-clarifier]').data('clarifier');
          var prob = parseInt($(event.target).closest('[data-problem]').attr('data-problem'));

          switch (rel) {
          case 'inc': c.increment(prob, vif); break;
          case 'dec': c.decrement(prob, vif); break;
          }
        });

      $(document.body)
        .on('click', 'button[rel="re-validate"]', function (event) {
          event.preventDefault();
          var $t = $('textarea.vif');
          var c  = $(event.target).closest('[data-has-clarifier]').data('clarifier');

          $t.val(c.patch($t.val()));
          $(event.target).closest('form').trigger('submit');
        });
    }
    this.e.attr('data-has-clarifier', '1').data('clarifier', this);
    return this;
  };

  window.Clarifier = Clarifier;
})(window, document);
