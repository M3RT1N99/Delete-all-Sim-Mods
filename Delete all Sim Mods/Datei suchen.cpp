#include <iostream>
#include <string>
#include <vector>
#include <filesystem>
#include <fstream>

using namespace std;
namespace fs = filesystem;
bool nosim = true;

vector<string> findFilesInDirectory(const string& directory, const string& fileName)
{
    vector<string> foundFiles;

for (const auto& entry : fs::directory_iterator(directory))
{
    if (entry.is_directory())
    {
        try
        {
            // Recursive call to search subdirectories
            vector<string> subdirectoryFiles = findFilesInDirectory(entry.path().string(), fileName);
            foundFiles.insert(foundFiles.end(), subdirectoryFiles.begin(), subdirectoryFiles.end());
        }
        catch (const std::exception& e)
        {
            std::cerr << L"Exception caught: " << e.what() << std::endl;
        }
    }
    else if (entry.is_regular_file() && entry.path().filename() == fileName)
    {
        foundFiles.push_back(entry.path().string());
    }
}

    return foundFiles;
}

bool containsUIOnlyFalse(const wstring& filePath)
{
    wifstream file(filePath);
    if (!file.is_open())
    {
        return false;
    }

    wstring line;
    while (getline(file, line))
    {
        if (line.find(L"ui_only") != wstring::npos && line.find(L"false") != wstring::npos)
        {
            return true;
        }
    }

    return false;
}

int main()
{
    std::string defaultPath = "C:\\ProgramData\\FAForever\\user\\My Games\\Gas Powered Games\\Supreme Commander Forged Alliance\\mods";

    // Suche nach mod_info.lua-Dateien im Standardpfad
    vector<string> foundFiles = findFilesInDirectory(defaultPath, "mod_info.lua");

    // Wenn keine mod_info.lua-Dateien gefunden wurden, fordern Sie den Benutzer auf, den Pfad einzugeben.
    if (foundFiles.empty())
    {
        std::wcout << L"mod_info.lua file not found. Please enter the path to the Lua folder: ";
        std::string userInput;
        std::getline(std::cin, userInput);

        // Suche nach mod_info.lua-Dateien im vom Benutzer eingegebenen Pfad
        foundFiles = findFilesInDirectory(userInput, "mod_info.lua");
    }

    // Wenn keine mod_info.lua-Dateien gefunden wurden, geben Sie eine Fehlermeldung aus.
    if (foundFiles.empty())
    {
        std::wcout << L"No mod_info.lua files found." << std::endl;
    }
    else
    {
        // Liste alle gefundenen Dateien auf
        nosim = true;
        for (const auto& file : foundFiles) 
        {
            wstring wfile = wstring(file.begin(), file.end());
            if (containsUIOnlyFalse(wfile))
            {
                std::wcout << L"The following mod_info.lua files were found: " << std::endl;
                std::wcout << fs::path(wfile).parent_path()<< std::endl;
                nosim = false;
            }
        }
        if (nosim == true)
        { 
            wcout << L"no sim mods found" << std::endl;
            system("pause");
            return 0;
        }
        std::wcout << std::endl << L"Are you sure you want to delete folders" << "? (y/n)";
        string yesno;
        getline(cin, yesno);
        for (const auto& file : foundFiles)
        {
            wstring wfile = wstring(file.begin(), file.end());
            std::wcout << wfile << std::endl;
            if (containsUIOnlyFalse(wfile))
            {
                if (yesno == "y")
                {
                    fs::remove_all(fs::path(wfile).parent_path());
                    std::wcout << L"Folder has Deleted: " << fs::path(wfile).parent_path() << std::endl;
                }

                else
                {
                    wcout << L"Operation cancelled." << endl;
                }
            }
        }
    }
    system("pause");

    return 0;
}