$(document).ready(function () {
  /*
   * When the text in an edit pane is changed, clear the contents of
   * the associated preview pne so that it will be regenerated when
   * the user next switches to it.
   */
  $(".richtext_container textarea").change(function () {
    var container = $(this).closest(".richtext_container");

    container.find(".tab-pane[id$='_preview']").empty();
  }).on("invalid", function () {
    var container = $(this).closest(".richtext_container");

    container.find("button[data-bs-target$='_edit']").tab("show");
  });

  /*
   * Install a handler to set the minimum preview pane height
   * when switching away from an edit pane
   */
  $(".richtext_container button[data-bs-target$='_edit']").on("hide.bs.tab", function () {
    var container = $(this).closest(".richtext_container");
    var editor = container.find("textarea");
    var preview = container.find(".tab-pane[id$='_preview']");
    var minHeight = editor.outerHeight() - preview.outerHeight() + preview.height();

    preview.css("min-height", minHeight + "px");
  });

  /*
   * Install a handler to switch to preview mode
   */
  $(".richtext_container button[data-bs-target$='_preview']").on("show.bs.tab", function () {
    var container = $(this).closest(".richtext_container");
    var editor = container.find("textarea");
    var preview = container.find(".tab-pane[id$='_preview']");

    if (preview.contents().length === 0) {
      preview.oneTime(500, "loading", function () {
        preview.addClass("loading");
      });

      preview.load(editor.data("previewUrl"), { text: editor.val() }, function () {
        preview.stopTime("loading");
        preview.removeClass("loading");
      });
    }
  });

  var updateHelp = function () {
    $(".richtext_container .richtext_help_sidebar:not(:visible):not(:empty)").each(function () {
      var container = $(this).closest(".richtext_container");
      $(this).children().appendTo(container.find(".tab-pane[id$='_help']"));
    });
    $(".richtext_container .richtext_help_sidebar:visible:empty").each(function () {
      var container = $(this).closest(".richtext_container");
      container.find(".tab-pane[id$='_help']").children().appendTo($(this));
      if (container.find("button[data-bs-target$='_help'].active").length) {
        container.find("button[data-bs-target$='_edit']").tab("show");
      }
    });
  };

  updateHelp();
  $(window).on("resize", updateHelp);
});
