using System;
using System.Windows.Forms;

namespace SmartPicker {
    static class Program {
        [STAThread]
        static void Main(string[] args) {
            try {
                using (var form = new Form()) {
                    form.TopMost = true;
                    form.TopLevel = true;
                    form.WindowState = FormWindowState.Minimized;
                    form.Show();
                    form.Activate();

                    using (var dialog = new OpenFileDialog()) {
                        dialog.Title = args.Length > 0 ? args[0] : "Select File";
                        dialog.Filter = args.Length > 1 ? args[1] : "Image Files (*.png;*.jpg;*.jpeg;*.webp;*.bmp)|*.png;*.jpg;*.jpeg;*.webp;*.bmp|All Files (*.*)|*.*";
                        dialog.Multiselect = false;
                        dialog.RestoreDirectory = true;
                        dialog.AutoUpgradeEnabled = true;

                        if (dialog.ShowDialog(form) == DialogResult.OK) {
                            Console.Write(dialog.FileName);
                        }
                    }
                    form.Close();
                }
            } catch {}
        }
    }
}

