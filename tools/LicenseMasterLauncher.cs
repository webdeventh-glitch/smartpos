using System;
using System.Diagnostics;
using System.IO;
using System.IO.Compression;
using System.Reflection;

internal static class LicenseMasterLauncher
{
    [STAThread]
    private static void Main(string[] args)
    {
        try
        {
            var asm = Assembly.GetExecutingAssembly();
            using (var stream = asm.GetManifestResourceStream("payload.zip"))
            {
                if (stream == null)
                {
                    throw new InvalidOperationException("Embedded payload.zip resource not found.");
                }

                string baseDir = Path.Combine(
                    Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                    "SmartPOS_LicenseMaster",
                    "v1.1.1_" + stream.Length);

                string exePath = Path.Combine(baseDir, "SmartPOS_LicenseMaster.exe");

                if (!File.Exists(exePath))
                {
                    if (Directory.Exists(baseDir))
                    {
                        Directory.Delete(baseDir, true);
                    }
                    Directory.CreateDirectory(baseDir);

                    using (var archive = new ZipArchive(stream, ZipArchiveMode.Read))
                    {
                        foreach (var entry in archive.Entries)
                        {
                            string destPath = Path.GetFullPath(Path.Combine(baseDir, entry.FullName));
                            if (!destPath.StartsWith(Path.GetFullPath(baseDir) + Path.DirectorySeparatorChar, StringComparison.OrdinalIgnoreCase))
                            {
                                continue;
                            }
                            if (string.IsNullOrEmpty(entry.Name))
                            {
                                Directory.CreateDirectory(destPath);
                            }
                            else
                            {
                                Directory.CreateDirectory(Path.GetDirectoryName(destPath));
                                using (var entryStream = entry.Open())
                                using (var outFile = File.Create(destPath))
                                {
                                    entryStream.CopyTo(outFile);
                                }
                            }
                        }
                    }
                }

                var psi = new ProcessStartInfo
                {
                    FileName = exePath,
                    WorkingDirectory = baseDir,
                    UseShellExecute = true
                };
                Process.Start(psi);
            }
        }
        catch (Exception ex)
        {
            System.Windows.Forms.MessageBox.Show(
                "Failed to launch SmartPOS License Master:\n\n" + ex.Message,
                "SmartPOS License Master",
                System.Windows.Forms.MessageBoxButtons.OK,
                System.Windows.Forms.MessageBoxIcon.Error);
        }
    }
}
