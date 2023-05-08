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

	// Check if directory exists
	if (!fs::exists(directory))
	{
		cerr << "Directory does not exist." << endl;
		return foundFiles;
	}

	// Check if filename is not empty
	if (fileName.empty())
	{
		cerr << "Filename is empty." << endl;
		return foundFiles;
	}

	try {

		for (const auto& entry : fs::directory_iterator(directory))
		{
			if (entry.is_directory())
			{
				try
				{
					// Recursive call to search subdirectories
					vector<string> subdirectoryFiles;
					subdirectoryFiles = findFilesInDirectory(entry.path().string(), fileName);
					foundFiles.insert(foundFiles.end(), subdirectoryFiles.begin(), subdirectoryFiles.end());
				}
				catch (const std::exception)
				{
					std::cerr << "Exception caught: " << std::endl;
				}
			}
			else if (entry.is_regular_file() && entry.path().filename() == fileName)
			{
				foundFiles.push_back(entry.path().string());
			}
		}
		return foundFiles;
	}
	catch (const std::exception)
	{
		std::cerr << "Exception caught: " << std::endl;
	}

	// Reset foundFiles vector to an empty vector before returning
	foundFiles.clear();
	return foundFiles;
}

bool containsUIOnlyFalse(const string& filePath)
{
	ifstream file(filePath);
	if (!file.is_open())
	{
		return false;
	}

	string line;
	while (getline(file, line))
	{
		if (line.find("ui_only") != string::npos && line.find("false") != string::npos)
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
		std::cout << "mod_info.lua file not found." << std::endl;

		// Suche nach mod_info.lua-Dateien im vom Benutzer eingegebenen Pfad
		while (foundFiles.empty())
		{
			std::cout << "Please enter the path to the Mods folder: ";
			std::string userInput;
			std::getline(std::cin, userInput);
			foundFiles = findFilesInDirectory(userInput, "mod_info.lua");

			if (foundFiles.empty())
			{
				std::cout << "No mod_info.lua files found at the specified location." << std::endl;
				std::cout << "Please try again." << std::endl;
			}
		}
	}

	// Wenn immer noch keine mod_info.lua-Dateien gefunden wurden, geben Sie eine Fehlermeldung aus.
	if (foundFiles.empty())
	{
		std::cout << "No mod_info.lua files found." << std::endl;
	}
	else
	{
		// Liste alle gefundenen Dateien auf
		nosim = true;
		for (const auto& file : foundFiles)
		{
			string filePath = string(file.begin(), file.end());
			if (containsUIOnlyFalse(filePath))
			{
				std::cout << "The following mod_info.lua files were found: " << std::endl;
				std::cout << fs::path(filePath).parent_path() << std::endl;
				nosim = false;
			}
		}
		if (nosim)
		{
			cout << "No sim mods found" << std::endl;
			system("pause");
			return 0;
		}
		std::cout << std::endl << "Are you sure you want to delete folders? (y/n)";
		string yesno;
		getline(cin, yesno);
		for (const auto& file : foundFiles)
		{
			std::cout << file << std::endl;
			if (containsUIOnlyFalse(file))
			{
				if (yesno == "y")
				{
					fs::remove_all(fs::path(file).parent_path());
					std::cout << "Folder has Deleted: " << fs::path(file).parent_path() << std::endl;
				}
				else
				{
					cout << "Operation cancelled." << endl;
				}
			}
		}
	}
	system("pause");
	return 0;
}