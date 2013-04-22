import sublime, sublime_plugin, os, subprocess, re
import functools
import exec_mtask

# the directory to work in
def working_dir():
    return sublime.active_window().folders()[0]

# invoke an executable with args and return output
def execute(bin, args):
    cmd = bin + " " + args
    print("$ " + cmd)
    p = subprocess.Popen(cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    out = p.communicate()

    if out[0] != '':
        return out[0]
    else:
        if out[1] != '': print(bin + ' error: ' + out[1])
        return out[1]

# invoke executable with args and return output
def run(args):
    os.chdir(working_dir())
    # out = exec_mtask.run(args)
    out = execute('haxelib', 'run mtask ' + args)
    return out

# is the plugin active
def is_active():
    return False
    if current_view() is None: return False
    if not os.path.exists(working_dir() + "/task/Build.hx"): return False
    return current_view().match_selector(current_index(), "source.hx")

# get the active view
def current_view():
    if sublime.active_window() is None: return None
    return sublime.active_window().active_view()

# the path of the active file
def current_file():
    return current_view().file_name()

# get the current index
def current_index():
    return current_view().sel()[0].begin()

# get the current position eg. /path/ClassName.hx@102
def current_pos():
    return current_file() + '@' + str(current_index())

# get the current char
def current_char():
    index = current_index()

    if index == 0: return view.substr(0)
    else: return current_view().substr(index - 1)

# get the current word
def current_word():
    end = current_index()
    if end == 0: return ""
    
    end = end - 1
    begin = end
    view = current_view()

    while begin > 1:
        char = view.substr(begin - 1)
        if char == " " or char == "\t": break
        begin -= 1
    
    return view.substr(sublime.Region(begin, end))

def output_to_completions(output):
    # TODO: figure out why ${} evals to null
    output = str.replace(output, "&&", "$")

    # print(">"+output+"<")
    if output == '': return []
    lines = str.split(output, "\n")
    lines = filter(filter_empty, lines)
    completions = map(line_to_completion, lines)
    return completions;

def filter_empty(string):
    pair = str.split(string, "|")
    return len(pair) > 1 and string != "" and string != "\n"

def line_to_completion(line):
    pair = str.split(line, "|")
    if len(pair) == 3: return (pair[2], pair[0], pair[1])
    return (pair[0], pair[1])

def get_completions(prefix):
    if (prefix == "new"):
        return output_to_completions(run('type new'))
    elif (prefix == ":"):
        return output_to_completions(run('type ' + current_pos()))
    elif (prefix == "."):
        return output_to_completions(run('field ' + current_pos()))
    else:
        return [];

def get_tasks():
    tasks = str.split(run("targets").strip(), "\n")
    result = []
    for task in tasks:
        name = str.split(task.strip(), "  ")[0]
        result.append(name)
    return result


def run_task(task):
    return run(task)

class MSublimeListener(sublime_plugin.EventListener):

    complete = False
    prefix = ""
    completions = []

    def on_query_completions(self, view, prefix, locations):
        if not MSublimeListener.complete: return [];
        if not is_active(): return []
        complete = False;
        
        if MSublimeListener.prefix != "":
            
            MSublimeListener.completions = get_completions(MSublimeListener.prefix)
            MSublimeListener.prefix = ""
            return MSublimeListener.completions

class HaxeComplete(sublime_plugin.TextCommand):

    def run(self, edit, insert="", prefix=""):
        MSublimeListener.complete = True
        MSublimeListener.prefix = prefix

        self.view.run_command("insert", { "characters": insert })
        self.view.run_command("save")
        self.view.run_command("auto_complete", { "disable_auto_insert":True })

class MassiveTask(sublime_plugin.TextCommand):

    def run(self, edit, insert="", prefix=""):
        tasks = get_tasks()
        sublime.Window.show_quick_panel(sublime.active_window(), tasks, functools.partial(self.on_done, tasks))

    def on_done(self, tasks, index):
        if (index == -1): return
        window = sublime.active_window()
        run_task(tasks[index])

class HaxeImport(sublime_plugin.TextCommand):

    def run(self, edit):

        view = self.view
        view.run_command("commit_completion")
        word = view.substr(view.word(view.sel()[0]))

        imports = view.find_all("^import (.+);")
        remove = None
        lookup = {'arg':False}
        nimports = []

        for region in imports:
            string = view.substr(region)
            imp = re.match("import (.+);", string).group(1)

            region = view.line(region)
            if remove is None: remove = region
            else: remove = remove.cover(region)

            if lookup.get(imp) == True: continue
            lookup[imp] = True
            nimports.append(string)
            
        view.erase(edit, remove)

        completions = MSublimeListener.completions
        for completion in completions:
            if completion[2] == word:
                nimports.append("import " + completion[0] + ";")
        
        new_imports = "\n".join(nimports)
        view.insert(edit, remove.begin(), new_imports)

class GotoDefinition(sublime_plugin.TextCommand):

    def run(self, edit):

        path = self.view.file_name()
        index = str(self.view.sel()[0].begin())
        definition = run('goto ' + current_pos())
        # print(">"+definition +"<")
        self.view.window().open_file(definition, sublime.ENCODED_POSITION)
