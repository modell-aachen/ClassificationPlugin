(function($) {
  $(function() {

    $(".jqRenameTag").each(function() {
      // ajaxification of renametagform
      var oldBackground;
      var $buttonIcon;
      var $this = $(this);
      var opts = $.extend({}, $this.metadata());

      function handleError(type, msg) {
        $this.find(".msg").html("<div class='foswiki"+type+"'>"+msg+"</div>");
      }

      function confirmDialog(elem, options) {
        $(elem).modal({ 
          close:false,
          onShow: function(dialog) {
            if (options.to == '') {
              dialog.data.find(".deleteMessage").show();
              dialog.data.find(".renameMessage").hide();
            } else {
              dialog.data.find(".deleteMessage").hide();
              dialog.data.find(".renameMessage").show();
            }
            dialog.data.find(".from").html(options.from);
            dialog.data.find(".to").html(options.to);
            dialog.data.find("#yes").click(function() {
              if (typeof(options.onAgree) == 'function') {
                options.onAgree(dialog);
              }
              return false;
            });
            dialog.data.find("#no").click(function() {
              if (typeof(options.onCancel) == 'function') {
                options.onCancel(dialog);
              }
              $.modal.close();
              return false;
            });
            $(window).trigger("resize.simplemodal");
          }
        });
      };

      $this.ajaxForm({
          dataType: 'html',
          beforeSubmit: function(data, form, options) {
            if (typeof(foswikiStrikeOne) != 'undefined') {
              foswikiStrikeOne($this[0]);
            }
            // add notification and spinner
            $buttonIcon = $this.find('.jqRenameTagSubmit .jqButtonIcon');
            oldBackground = $buttonIcon.css('background-image');
            $buttonIcon.css('background-image', 'url('+foswiki.getPreference("PUBURLPATH")+'/'+foswiki.getPreference("SYSTEMWEB")+'/JQueryPlugin/images/spinner.gif)');
            $this.find(".msg").empty();
          },
          success: function(data, status) {
            // restore old icon and notify
            $buttonIcon.css('background-image', oldBackground);
            handleError('Success', data);
            $this.find("input[type=text]").val(""); 
            $this.find("#renameClear").click();
            if (typeof(opts.onsuccess) == 'function') {
              opts.onsuccess.call(this, $this);
            }
          },
          error: function(xhr, status) {
            // restore old icon and warn
            $buttonIcon.css('background-image', oldBackground);
            handleError('Alert', "Error: "+xhr.responseText);
            if (typeof(opts.onerror) == 'function') {
              opts.onerror.call(this, $this);
            }
          }
      });

      $this.find(".jqRenameTagSubmit").click(function() {
        var from = new Array;
        $this.find("input[name=from]").each(function() {
          var val = $(this).val();
          if (val) {
            from.push(val);
          }
        });
        if (from.length == 0) {
          return false;
        }
        from = from.join(", ");
        var to = $this.find("input[name=to]").val();

        confirmDialog("#confirmRenameTag", {
          onAgree: function(dialog) {
            $this.submit();
            $.modal.close();
            return false;
          },
          from: from,
          to: to
        });
        return false;
      });
    });
  });
})(jQuery);

function showHideAllTags () {
  var $alltags = jQuery("#alltags");
  var $button = jQuery("#show_hide_tags .jqButtonIcon");
  if ($alltags.is(":hidden")) {
    var oldBackground = $button.css('background-image');
    $button.css('background-image','url('+foswiki.getPreference("PUBURLPATH")+'/'+foswiki.getPreference("SYSTEMWEB")+'/JQueryPlugin/plugins/spinner/spinner.gif)');
    $alltags.load(
      foswiki.getPreference("SCRIPTURL")+'/rest/RenderPlugin/template/rest', {
        name:'oopsmore',
        expand:'showalltags',
        topic:foswiki.getPreference("WEB")+"."+foswiki.getPreference("TOPIC")
      }, function() {
        $alltags.slideDown();
        jQuery("#show_hide_tags .jqButtonIcon").css('background-image',oldBackground).text("Hide all tags");;
      }
    );
  } else {
    $alltags.hide();
    jQuery("#show_hide_tags .jqButtonIcon").text("Show all tags");
  }
  return false;
}
