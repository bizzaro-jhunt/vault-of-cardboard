;(function (jQuery, exported, document, undefined) {
  var err = function ($f, e, msg) {
    msg = $f.attr('data-error-'+e) || $f.attr('data-error') || msg;
    $f.closest('p')
      .addClass('form-validation-failed')
      .append('<span class="form-validation-error">'+msg+'</span>');
  };

  jQuery.fn.validate = function (action, options) {
    if (action == 'reset') {
      this.find('.oops').hide();
      this.find('.form-validation-error').remove();
      this.find('.form-validation-failed').removeClass('form-validation-failed');
      return this;
    }

    if (action == 'validate') {
      this.find('[data-validate]:visible').each(function (_, e) {
        var $field = $(e);
        var  value = $field.val().replace(/(^\s+|\s+$)/, '');
        console.log('validating "%s"', value);

        var validations = $field.attr('data-validate').split(/\s*;\s*/);
        for (var i = 0; i < validations.length; i++) {
          var type = validations[i],
              qual = undefined,
            format = 'text';

          var m = type.match(/^(.*?)=(.*)$/);
          if (m) {
            type = m[1];
            qual = m[2];
          }

          switch (type) {
          case 'present':
            if (qual != undefined) {
              console.log('data-validation warning on field "%s": _present_ validations do not take a qualifier... (have "%s=%s")', $field.attr('name'), type, qual);
            }
            if (value == "") {
              err($field, 'if-missing',
                  'This field is required.');
              return;
            }
            break;

          case 'min':
            if (qual == undefined) {
              console.log('data-validation warning on field "%s": _min_ validations require a qualifier...', $field.attr('name'));
              break;
            }
            qual = parseFloat(qual);
            if (isNaN(qual)) {
              console.log('data-validation warning on field "%s": _min_ validations require a numeric qualifier (have "%s=%s")', $field.attr('name'), type, qual);
              break;
            }

            switch (format) {
            case 'text':
              if (value.length < qual) {
                err($field, 'out-of-bounds',
                    'This field must be at least '+qual.toString()+' characters long.');
                return;
              }
              break;

            default:
              console.log('data-validation warning on field "%s": unknown data type used in _min_ validation: %v', $field.attr('name'), format);
              break;
            }
            break;

          case 'max':
            if (qual == undefined) {
              console.log('data-validation warning on field "%s": _max_ validations require a qualifier...', $field.attr('name'));
              break;
            }
            var unit = qual.substr(-1);
            qual = parseFloat(qual);
            if (isNaN(qual)) {
              console.log('data-validation warning on field "%s": _max_ validations require a numeric qualifier (have "%s=%s")', $field.attr('name'), type, qual);
              break;
            }
            switch (unit) {
            case "k":
            case "K": qual *= 1000; break;
            case "m":
            case "M": qual *= 1000 * 1000; break;
            }

            switch (format) {
            case 'text':
              if (value.length > qual) {
                err($field, 'out-of-bounds',
                    'This field can be no more than '+qual.toString()+' characters long.');
                return;
              }
              break;

            default:
              console.log('data-validation warning on field "%s": unknown data type used in _max_ validation: %v', $field.attr('name'), format);
              break;
            }
            break;

          case 'format':
            if (qual == undefined) {
              console.log('data-validation warning on field "%s": _max_ validations require a qualifier...', $field.attr('name'));
              break;
            }
            switch (qual) {
            case 'format': break;
            case 'date':
              format = 'date';
              if (!value.match(/^[0-9]{4}\s*[./-]\s*[0-9]{1,2}\s*[./-]\s*[0-9]{1,2}$/)) {
                err($field, 'format',
                    'This field must be formatted like a date, i.e. <em>DD/MM/YYYY</em>.');
              }
            default:
              console.log('data-validation warning on field "%s": unknown format specified for _format_ validation: %v', $field.attr('name'), qual);
              break;
            }
            break;

          default:
            console.log('data-validation warning on field "%s": unknown validation _%s_ (have %s=%s)', type, type, qual);
            break;
          }
        }
      });

      if (this.find('.form-validation-failed').length == 0) {
        return true;
      }
      this.find('.form-validation-failed').first().find('input, textarea').focus();
      return false;
    }

    console.log('FAILED to validate with action "%s" (unrecognized)', action);
    return this;
  };
})(jQuery, window, document);
