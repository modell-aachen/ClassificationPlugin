/*
 * jQuery TagSelector plugin 1.1
 *
 * Copyright (c) 2008 Michael Daum http://michaeldaumconsulting.com
 *
 * Dual licensed under the MIT and GPL licenses:
 *   http://www.opensource.org/licenses/mit-license.php
 *   http://www.gnu.org/licenses/gpl.html
 *
 * Revision: $Id$
 *
 */
(function($) {

  /***************************************************************************
   * plugin definition 
   */
  $.fn.tagSelector = function(options) {
    writeDebug("called tagSelector()");
   
    // build main options before element iteration
    var opts = $.extend({}, $.fn.tagSelector.defaults, options);
   
    // implementation ********************************************************
    return this.each(function() {
      $this = $(this);

      // build element specific options. 
      // note you may want to install the Metadata plugin
      var thisOpt = $.meta ? $.extend({}, opts, $this.data()) : opts;

      // get interface elements
      var $input = $(thisOpt.input, this);
      var $tagCloud = $(thisOpt.tagCloud, this);

      //writeDebug("input="+$input);
      //writeDebug("tagCloud="+$tagCloud);

      var initialTags;

      // toggle a tag in the input field and the cloud ***********************
      function toggleTag(tag) {
        //writeDebug("called toggleTag("+tag+")");

        var currentValues = $input.val() || '';
        currentValues = currentValues.split(/\s*,\s*/);
        var found = false;
        var newValues = new Array();
        for (var i = 0; i < currentValues.length; i++)  {
          var value = currentValues[i];
          if (!value) 
            continue;
          if (value == tag) {
            found = true;
          } else {
            if (value.indexOf(tag) != 0) {
              newValues.push(value);
            }
          }
        }

        if (!found) {
          newValues.push(tag)
        }
        //writeDebug("newValues="+newValues);

        setTags(newValues);
      }

      // add a tag to the selection ******************************************
      function setTags(tags, doSort) {
        //writeDebug("called setTags("+tags+")");

        clearSelection();
        var values;
        if (typeof(tags) == 'object') {
          values = tags;
        } else {
          values = tags.split(/\s*,\s*/);
        }
        if (!values.length) {
          return;
        }
        var tmpValues = new Array()
        for (var i = 0; i < values.length; i++) {
          tmpValues.push(values[i].replace(/([^0-9A-Za-z_])/, '\\$1'));
        }
        var filter = "#"+tmpValues.join(",#");
        //writeDebug("filter="+filter);
        $tagCloud.find(filter).addClass("current");
        if (doSort) {
          values = values.sort();
        }
        $input.val(values.join(", "));
      }

      // clear selection *****************************************************
      function clearSelection() {
        $input.val("");
        $("a", $tagCloud).removeClass('current typed');
      }
 
      // reset selection *****************************************************
      function resetSelection() {
        setTags(initialTags);
      }

      // init ****************************************************************
      function init() {
        // events 
        writeDebug("called init()");
        var tags = [];
        $this.find('.clsTagCloud a').each(function() {
          tags.push([$(this).text(),$(this).attr('title')]);
        });
        writeDebug("tags = "+tags);
        $input.autocomplete(
          tags,
          {
            multiple: true,
            autoFill: true,
            formatItem: function(tag, i, total) {
              return '<table width="100%"><tr><td align="left">'+tag[0]+'</td><td align="right">'+tag[1]+'</td></tr></table>';
            },
            formatMatch: function(tag, i, total) {
              return tag[0];
            }
          }
        ).result(function(event, data, formatted) {
          $tagCloud.find("#"+formatted).addClass("current");
        });
        $(thisOpt.clearButton, $this).click(function() {
          clearSelection();
          this.blur();
        });
        $(thisOpt.resetButton, $this).click(function() {
          resetSelection();
          this.blur();
        });

        initialTags = new Array();
        // tag cloud links
        $("a", $tagCloud).click(function() {
          writeDebug("click");
          this.blur(); 
          toggleTag($(this).attr('id'));
        }).filter(".current").each(function() {
          var term = $(this).attr('id');
          initialTags.push(term);
        });

        resetSelection();
      }

      init();
    });
  };

  /***************************************************************************
   * plugin defaults
   */
  $.fn.tagSelector.defaults = {
    debug: false,
    input: ".clsTagCloudInput",
    tagCloud: ".clsTagCloud",
    clearButton: ".clsClearButton",
    resetButton: ".clsResetButton"
  };

  /***************************************************************************
   * private static function for debugging using the firebug console
   */
  function writeDebug(msg) {
    if ($.fn.tagSelector.defaults.debug) {
      msg = "DEBUG: TagSelector - "+msg;
      if (window.console && window.console.log) {
        window.console.log(msg);
      } else { 
        //alert(msg);
      }
    }
  };
 
})(jQuery);
