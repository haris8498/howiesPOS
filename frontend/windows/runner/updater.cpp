#include <windows.h>
#include <shellapi.h>
#include <iostream>
#include <filesystem>
#include <string>
#include <chrono>
#include <thread>
#include <algorithm>
#include <vector>
#include <cwctype>

namespace fs = std::filesystem;

// Checks whether a filename matches protected persistent patterns (.env, *.db, *.key, etc.)
bool IsProtectedFile(const fs::path& path) {
    std::wstring filename = path.filename().wstring();
    std::transform(filename.begin(), filename.end(), filename.begin(), [](wchar_t c) -> wchar_t {
        return static_cast<wchar_t>(::towlower(c));
    });

    if (filename == L".env" || filename == L".env.example") {
        return true;
    }
    if (filename.length() >= 3 && filename.substr(filename.length() - 3) == L".db") {
        return true;
    }
    if (filename.length() >= 4 && filename.substr(filename.length() - 4) == L".key") {
        return true;
    }
    if (filename.length() >= 7 && filename.substr(filename.length() - 7) == L".sqlite") {
        return true;
    }
    if (filename.length() >= 8 && filename.substr(filename.length() - 8) == L".sqlite3") {
        return true;
    }
    return false;
}

int WINAPI wWinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, PWSTR pCmdLine, int nCmdShow) {
    int argc = 0;
    LPWSTR* argv = CommandLineToArgvW(GetCommandLineW(), &argc);

    if (argc < 5) {
        // Expected args: updater.exe <old_pid> <source_dir> <target_dir> <exe_name>
        if (argv) LocalFree(argv);
        return 1;
    }

    DWORD oldPid = static_cast<DWORD>(_wtoi(argv[1]));
    fs::path sourceDir(argv[2]);
    fs::path targetDir(argv[3]);
    std::wstring exeName = argv[4];

    LocalFree(argv);

    // 1. Wait for running POS process to terminate
    if (oldPid > 0) {
        HANDLE hProcess = OpenProcess(SYNCHRONIZE, FALSE, oldPid);
        if (hProcess != NULL) {
            WaitForSingleObject(hProcess, 30000); // Max 30 seconds wait
            CloseHandle(hProcess);
        }
    }

    // Brief sleep to ensure Windows releases all file handles
    std::this_thread::sleep_for(std::chrono::milliseconds(600));

    // Resolve source directory: If sourceDir doesn't contain exeName but has a single subfolder that does
    if (!fs::exists(sourceDir / exeName)) {
        for (const auto& entry : fs::directory_iterator(sourceDir)) {
            if (entry.is_directory() && fs::exists(entry.path() / exeName)) {
                sourceDir = entry.path();
                break;
            }
        }
    }

    // 2. Recursively copy files from sourceDir to targetDir
    std::error_code ec;
    try {
        for (const auto& entry : fs::recursive_directory_iterator(sourceDir, ec)) {
            if (ec) continue;

            const fs::path relative = fs::relative(entry.path(), sourceDir, ec);
            if (ec) continue;

            const fs::path destination = targetDir / relative;

            if (entry.is_directory()) {
                fs::create_directories(destination, ec);
            } else if (entry.is_regular_file()) {
                if (IsProtectedFile(entry.path())) {
                    continue;
                }

                // Copy with retry for transient file locks
                bool copied = false;
                for (int attempt = 0; attempt < 5; ++attempt) {
                    if (fs::exists(destination)) {
                        fs::remove(destination, ec);
                    }
                    fs::copy_file(entry.path(), destination, fs::copy_options::overwrite_existing, ec);
                    if (!ec) {
                        copied = true;
                        break;
                    }
                    std::this_thread::sleep_for(std::chrono::milliseconds(300));
                }
            }
        }
    } catch (...) {
        // Continue to restart even if a non-critical file encountered an error
    }

    // 3. Restart the updated application
    fs::path targetExe = targetDir / exeName;
    if (fs::exists(targetExe)) {
        STARTUPINFOW si = { sizeof(si) };
        PROCESS_INFORMATION pi = { 0 };

        std::wstring cmdLine = L"\"" + targetExe.wstring() + L"\"";
        std::vector<wchar_t> cmdBuffer(cmdLine.begin(), cmdLine.end());
        cmdBuffer.push_back(0);

        if (CreateProcessW(
                targetExe.c_str(),
                cmdBuffer.data(),
                NULL,
                NULL,
                FALSE,
                0,
                NULL,
                targetDir.c_str(),
                &si,
                &pi)) {
            CloseHandle(pi.hProcess);
            CloseHandle(pi.hThread);
        }
    }

    // 4. Cleanup temporary update files
    try {
        fs::remove_all(sourceDir, ec);
    } catch (...) {
    }

    return 0;
}
