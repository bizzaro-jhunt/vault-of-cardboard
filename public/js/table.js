;(function (jQuery, document, undefined) {

  jQuery.fn.sortableTable = function (options) {
    var $tbody = this.find('tbody');
    var $thead = this.find('thead');

    $thead.find('th.sortable').each(function (_, e) {
      var $th  = $(e);
      var idx  = $th.index();
      var type = $th.is('[data-sort-as]') ? $th.attr('data-sort-as') : 'text';

      $th.append('<span>');

      $th.on('click', function (event) {
        console.log(this);
        var mode = ($(this).is('.sort.asc') ? -1 : 1);
        $(this).closest('thead').find('th').removeClass('sort asc desc');
        $(this).addClass('sort').addClass(mode == 1 ? 'asc' : 'desc');

        var rows = [];
        $tbody.find('tr').each(function (_, e) {
          var $tr = $(e).detach();
          var $td = $($tr.find('td')[idx]);
          var key = $td.is('[data-sort]') ? $td.attr('data-sort') : $td.text();

          switch (type) {
          case 'number': key = parseFloat(key); break;
          default:        break;
          }

          rows.push([key, $tr]);
        });

        rows.sort(function (a, b) {
          return mode * (a[0] > b[0] ?  1 :
                         a[0] < b[0] ? -1 : 0);
        });

        for (var i = 0; i < rows.length; i++) {
          $tbody.append(rows[i][1]);
        }
      });
    });
  };

})(jQuery, document);
