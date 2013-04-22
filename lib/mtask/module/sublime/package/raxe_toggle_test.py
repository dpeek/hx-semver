import sublime, sublime_plugin, subprocess, re, functools, os, operator
import raxe, haxe

class RaxeToggleTest(sublime_plugin.TextCommand):
    def run(self, edit):

        qualified_class_name = ""

        # We could look in file for package decleration but would like to generate even for empty file

        file_path, file_name = os.path.split(self.view.file_name())
        class_name, extension = os.path.splitext(file_name)
        package = ""
        current_root_dir = ""
        qualified_class_name = ""
        failed_to_locate_root = False
        command = ""

        if class_name.endswith("Test"):
            current_root_dir = "test"
            command = "create class for "
        else:
            current_root_dir = "src"
            command = "create test for "

        f = open(self.view.file_name(), "r")
        contents = f.read()
        f.close()

        # Fist check the file for a package decleration as more accurate as
        # src may not be the root of the src path.

        # TODO: Take comments at start of file into consideration. ms 29/7/11
        contents = contents.lstrip(" \t\r\n")
        if contents.startswith("package"):
            packageLine = contents[:contents.find("\n")]
            packageLine = packageLine[7:]
            package = packageLine.strip(" ;\t\r\n")
        else:
            # If no package decleration found then assume 'test' or 'src' is root
            parts = file_path.split(current_root_dir)
            partCount = len(parts)
            if partCount > 1:
                package = parts[partCount - 1]
                if package[0] == "/":
                    package = n[1:]
                package = n.replace("/", ".")
                print (qualified_class_name)
            else:
                failed_to_locate_root = True

        if not failed_to_locate_root:
            if len(package) > 0:
                package = package + "."
        
            qualified_class_name = package + class_name
            result = raxe.run(command + qualified_class_name)
            parts = result.split("create file:")
            partCount = len(parts)
            if partCount > 1:
                line = parts[1].split("\n")[0]
                created_file_path = line.strip(" \t\r\n")
                created_file_path = os.path.join(haxe.resolve_working_dir(), created_file_path)
                self.view.window().open_file(created_file_path)
                # print("created_file_path " + created_file_path)


        # self.view.window().open_file(target_file_path)

        # forcing naming and dir structure conventions
        # test_dir = "test"
        # src_dir = "src"

        # file_path, file_name = os.path.split(self.view.file_name())
        # base_file_name, extension = os.path.splitext(file_name)


        # if base_file_name.endswith("Test"):
        #     target_file_name = base_file_name[:-4] + extension
        #     current_root_dir = src_dir
        #     target_root_dir = test_dir
        # else:
        #     target_file_name = base_file_name + "Test" + extension
        #     current_root_dir = test_dir
        #     target_root_dir = src_dir

        # print("targetfilename " + target_file_name)

        # package_path = ""

        # while True:
        #     parent_path, current_dir_name = os.path.split(file_path)
        #     target_root_path = os.path.join(parent_path, target_root_dir)

        #     if current_dir_name == current_root_dir and os.path.exists(target_root_path):
        #         target_file = os.path.join(target_root_path, package_path, target_file_name)

        #         if not os.path.exists(target_file):
        #             parent_dir = os.path.dirname(target_file)
        #             if not os.path.exists(parent_dir):
        #                 os.makedirs(parent_dir)

        #             f = open(target_file, "w")
        #             f.write("")
        #             f.close()

        #         self.view.window().open_file(targetfile)
        #         break;
            
        #     else if parent_path == "/":
        #         break;

        #     package_path = os.path.join(package_path, current_dir_name)


        # packagepath = ""
        # while True:
        #     root_dir_path = os.path.join(filepath, target_root_dir)

        #     if os.path.exists(root_dir_path):
        #         targetfile = os.path.join(testpath, packagepath, targetfilename)

        #         if not os.path.exists(targetfile):
        #             d = os.path.dirname(targetfile)
        #             if not os.path.exists(d):
        #                 os.makedirs(d)

        #             f = open(targetfile, "w")
        #             f.write(targetfilename)
        #             f.close()

        #         #print(self.view.window())
                
        #         self.view.window().open_file(targetfile)
        #         #  self.window.open_file(new_path)

        #         print(targetfile)
        #         print(packagepath)
        #         break
            
        #     if filepath == "/":
        #         break
            
        #     (filepath, currentdir) = os.path.split(filepath)
        #     packagepath = os.path.join(packagepath, currentdir)

