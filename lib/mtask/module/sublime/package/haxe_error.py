import sublime, sublime_plugin, re, os

# This module parses errors from Haxe compiler output and displays them to the 
# user in a quick select panel. Selecting an error with open the file at the 
# position of the error. Errors are also stored in a settings object, so that 
# opening a file with errors with highlight them in a fetching color. Placing 
# selection in error with display the error in the status bar.

# the error caches
errors = []
statuses = []

# displays the errors contained in output to the user in a quick panel, 
# allowing them to navigate to them
def show(output):
    global errors
    global statuses

    window = sublime.active_window()
    view = window.active_view()

    # reset state
    view.erase_regions("haxe_errors")
    view.erase_status("haxe_errors")

    # parse errors
    statuses = []
    errors = parse_errors(output)

    # show quick panel
    def error_to_message(error): return error["file"] + ":" + str(error["line"]) + " " + error["message"]
    messages = map(error_to_message, errors)
    sublime.Window.show_quick_panel(window, messages, goto_error)

# when the quick panel completes, goto the selected error
def goto_error(index):
    if (index == -1): return
    window = sublime.active_window()
    window.open_file(errors[index]["subl"], sublime.ENCODED_POSITION)

# parses errors from haxe compiler output into an array of objects with the 
# following fields:
#    path: the absolute path to the file containing the error
#    subl: the sublime encoded file path of the error (path/file:line:column)
# message: a succinct error message, without file/position info
#   lines: a boolean indicating whether the error spans lines, or characters on 
#          on a single line
#   begin: the beginning column/line of the error depending on "lines"
#     end: the end column/line
def parse_errors(output):
    errors = [];

    for match in re.finditer("([a-zA-Z0-9_/]+.[a-z]+):(\d+): (characters|lines) (\d+)-(\d+) : (?!Warning)(.+)", output):

        # extract groups
        path = match.group(1)
        line = int(match.group(2))
        lines = (match.group(3) == "lines")
        begin = int(match.group(4))
        end = int(match.group(5))
        message = match.group(6)

        # determine paths
        abspath = os.path.abspath(path)
        path = re.split("(src/|test/)", path).pop()
        subl = abspath + ":" + match.group(2)

        # if line range begin is column to open at
        if not lines: subl += ":" + str(begin + 1)

        # clean up message
        message = ": ".join(message.split(" : "))

        # append message
        errors.append({ "path":abspath, "subl":subl, "message":message, 
            "file":path, "line":line, "lines":lines, "begin": begin, "end":end })
        
    return errors

# this plugin listens for window activations and changes in selection and 
# displays errors for haxe source based on the last error set
class HaxeErrorListener(sublime_plugin.EventListener):

    def on_load(self, view):
        self.show_errors(view)
        
    def on_activated(self, view):
        self.show_errors(view)

    def show_errors(self, view):
        if view.window() is None: return

        messages = [];
        regions = []
        
        for error in errors:
            if (error["path"] != view.file_name()): continue;

            if error["lines"]:
                begin = view.text_point(error["begin"] - 1, 0)
                end = view.text_point(error["end"], 0)
            else:
                begin = view.text_point(error["line"] - 1, error["begin"])
                end = view.text_point(error["line"] - 1, error["end"])
            
            messages.append(begin)
            messages.append(end)
            messages.append(error["message"])

            region = sublime.Region(begin, end)
            regions.append(region)
        
        view.add_regions("haxe_errors", regions, "support.type.exception", "dot", sublime.DRAW_OUTLINED)
        
        global statuses
        statuses = messages;

    def on_selection_modified(self, view):

        if statuses is None: return
        messages = [];

        for i in range(0, len(statuses), 3):
            begin = int(statuses[i])
            end = int(statuses[i + 1])
            message = statuses[i + 2]
            if (sublime.Region(begin, end).contains(view.sel()[0])):
                messages.append(message)

        view.set_status("haxe_errors", " and ".join(messages))
