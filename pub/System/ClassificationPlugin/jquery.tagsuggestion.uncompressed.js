jQuery(function($) {
  $(".clsTagSuggestion:not(.jqInitedTagSuggestion)").livequery(function() {
    var $this = $(this);
    $this.addClass("jqInitedTagSuggestion");
    var $input = $this.parents(".clsTagEditor").find(".jqTextboxList:first");
    var val = $this.text();
    $this.click(function(e) {
      $input.trigger("AddValue", val);
      $this.parent().remove();
      e.preventDefault();
      return false;
    });
  });
});
