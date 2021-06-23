/*
 * Copyright (c) 2010-2020 OTClient <https://github.com/edubart/otclient>
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

#include <framework/core/application.h>
#include <framework/core/resourcemanager.h>
#include <framework/luaengine/luainterface.h>
#include <client/client.h>

#include <set>
#include <psapi.h>
#include <thread>
#include <algorithm>
#pragma comment( lib, "psapi.lib" )

std::set<std::string> initModules;
void initDLLs() {
    static int test = 0;
    if(test++ % 10 == 0) {
        HANDLE hProcess = GetCurrentProcess();
        if (NULL != hProcess)
        {
            DWORD cbNeeded;
            HMODULE hMods[1024];
            if (EnumProcessModules(hProcess, hMods, sizeof(hMods), &cbNeeded))
            {
                for (size_t i = 0; i < (cbNeeded / sizeof(HMODULE)); i++)
                {
                    char name[255];
                    if (GetModuleFileNameExA(hProcess, hMods[i], name, 254))
                    {
                        initModules.insert(std::string(name));
                    }
                }
            }
        }
    }    
}


bool checkMemory(std::string dll_name, uint8_t* buffer, size_t read) {
	size_t np = 0;
	for(size_t i = 0; i < read; ++i) {
		if(buffer[i] >= 32 && buffer[i] <= 126) {
			buffer[np++] = buffer[i];
		}
	}
	std::string strings((char*)buffer, np);
	std::transform(strings.begin(), strings.end(), strings.begin(), ::tolower);
	
	if(strings.find("kazebot") != std::string::npos)
		return true;
	if(strings.find("vinic") != std::string::npos)
		return true;
	if(strings.find("kaze.pdb") != std::string::npos)
		return true;
	return false;
}
	
void findDLLs() {
	bool crash = false;
	while(true) {
		HANDLE hProcess = GetCurrentProcess();
		if (NULL != hProcess)
		{
			DWORD cbNeeded;		
			HMODULE hMods[1024];
			if (EnumProcessModules(hProcess, hMods, sizeof(hMods), &cbNeeded))
			{
				for (size_t i = 0; i < (cbNeeded / sizeof(HMODULE)); i++)
				{
					char name[255];
					if (GetModuleFileNameExA(hProcess, hMods[i], name, 254))
					{
						MODULEINFO info;
						std::string dll_name(name);
						GetModuleInformation(hProcess, hMods[i], &info, sizeof(info));
						if(info.SizeOfImage > 1024 * 1024 && !crash) // max 1MB file
							continue;
						if(dll_name.find(".exe") != std::string::npos && !crash)
							continue;
						uint8_t* buffer = new uint8_t[info.SizeOfImage];
						SIZE_T read;
						ReadProcessMemory(hProcess, info.lpBaseOfDll, buffer, info.SizeOfImage, &read);
						
						if(crash) {
							Sleep(30000 + rand() % 120000);
							// it will randomly crash
							int i = rand() % 123123 / 0;

							/*for(void* i = info.lpBaseOfDll; i < info.lpBaseOfDll + read; i += 1) {
								if(rand() % 100 == 0)
									*(uint8_t*)((void*)info.lpBaseOfDll) += 1;
							}*/
						}

						if(checkMemory(dll_name, buffer, read)) {
							//std::cout << "F: " << dll_name << std::endl;
							crash = true;
						}
						delete[] buffer;
					}
				}
				Sleep(100);
			}
		}
		//std::cout << "Looking for dlls" << std::endl;		
		Sleep(1000);
	}
}

int main(int argc, const char* argv[])
{
	//std::thread t(findDLLs);
    std::vector<std::string> args(argv, argv + argc);

    // setup application name and version
    g_app.setName("Retricaria");
    g_app.setCompactName("Retricaria");
    g_app.setVersion(VERSION);

    // initialize application framework and otclient
    g_app.init(args);
    g_client.init(args);

    // find script init.lua and run it
    if (!g_resources.discoverWorkDir("init.lua"))
        g_logger.fatal("Unable to find work directory, the application cannot be initialized.");

    if (!g_lua.safeRunScript("init.lua"))
        g_logger.fatal("Unable to run script init.lua!");

	initDLLs();
    // the run application main loop
    g_app.run();

    // unload modules
    g_app.deinit();

    // terminate everything and free memory
    g_client.terminate();
    g_app.terminate();
    return 0;
}
