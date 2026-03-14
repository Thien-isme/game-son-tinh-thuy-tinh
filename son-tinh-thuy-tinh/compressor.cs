using System;
using System.IO;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Threading.Tasks;

class Program {
    static void Main() {
        string dir = @"d:\GameWithGodot\game-son-tinh-thuy-tinh\son-tinh-thuy-tinh\assets\sprites";
        if(!Directory.Exists(dir)) {
            Console.WriteLine("Directory not found!");
            return;
        }
        string[] files = Directory.GetFiles(dir, "*.png", SearchOption.AllDirectories);
        Console.WriteLine(string.Format("Found {0} PNG files. Resizing by 50%...", files.Length));
        
        int count = 0;
        int processedFiles = 0;
        
        Parallel.ForEach(files, new ParallelOptions { MaxDegreeOfParallelism = Environment.ProcessorCount }, file => {
            try {
                bool optimized = false;
                // Read fully into memory to avoid File Locking
                byte[] bytes = File.ReadAllBytes(file);
                using (MemoryStream ms = new MemoryStream(bytes)) {
                    using (Image img = Image.FromStream(ms)) {
                        if (img.Width > 150 && img.Height > 150) {
                            int newW = img.Width / 2;
                            int newH = img.Height / 2;
                            using (Bitmap bmp = new Bitmap(newW, newH)) {
                                using (Graphics g = Graphics.FromImage(bmp)) {
                                    g.InterpolationMode = InterpolationMode.Bicubic;
                                    g.CompositingQuality = CompositingQuality.HighSpeed;
                                    g.DrawImage(img, 0, 0, newW, newH);
                                }
                                string tempFile = file + ".tmp";
                                bmp.Save(tempFile, System.Drawing.Imaging.ImageFormat.Png);
                                optimized = true;
                            }
                        }
                    }
                }
                
                if (optimized) {
                    File.Delete(file);
                    File.Move(file + ".tmp", file);
                    System.Threading.Interlocked.Increment(ref count);
                }
            } catch (Exception ex) { 
                Console.WriteLine(string.Format("Error on {0}: {1}", file, ex.Message));
                if (File.Exists(file + ".tmp")) {
                    try { File.Delete(file + ".tmp"); } catch { }
                }
            }
            
            int current = System.Threading.Interlocked.Increment(ref processedFiles);
            if (current % 1000 == 0 || current == files.Length) {
                Console.WriteLine(string.Format("Processed {0}/{1} files (Resized {2})...", current, files.Length, count));
            }
        });
        Console.WriteLine(string.Format("Finished! Successfully resized {0} files.", count));
    }
}
