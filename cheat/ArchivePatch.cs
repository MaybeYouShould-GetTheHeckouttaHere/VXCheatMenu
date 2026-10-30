using System;
using System.IO;
using System.Text;
using System.Security.Cryptography;

// RGSS3 ignores loose load_data files when Game.rgss3a is present. Redirect
// only the existing Scripts entry to an appended bootstrap. All asset offsets
// and encrypted asset bytes stay untouched. A journal permits exact reversal.
public static class VXCheatArchive {
    sealed class Entry {
        public long Position;
        public uint Offset, Size, Key, TableKey;
        public byte[] Header;
    }
    static byte[] Read(BinaryReader reader, int size) {
        byte[] data = reader.ReadBytes(size);
        if (data.Length != size) throw new IOException("Truncated RGSS archive");
        return data;
    }
    static Entry Find(FileStream file, string scripts) {
        file.Position = 0;
        var reader = new BinaryReader(file, Encoding.UTF8, true);
        if (Encoding.ASCII.GetString(Read(reader,8)) != "RGSSAD\0\x03")
            throw new IOException("Only standard RGSS3 encrypted archives are supported");
        uint key = unchecked(reader.ReadUInt32()*9+3);
        scripts = scripts.Replace('/','\\');
        for (int i=0;i<1000000;i++) {
            long position = file.Position;
            byte[] header = Read(reader,16);
            uint offset = BitConverter.ToUInt32(header,0)^key;
            if (offset == 0) break;
            uint size = BitConverter.ToUInt32(header,4)^key;
            uint dataKey = BitConverter.ToUInt32(header,8)^key;
            uint length = BitConverter.ToUInt32(header,12)^key;
            if (length > 65536 || (long)offset+size > file.Length) throw new IOException("Invalid RGSS3 index");
            byte[] name = Read(reader,(int)length);
            byte[] mask = BitConverter.GetBytes(key);
            for (int j=0;j<name.Length;j++) name[j] ^= mask[j%4];
            if (String.Equals(Encoding.UTF8.GetString(name).Replace('/','\\'),scripts,StringComparison.OrdinalIgnoreCase))
                return new Entry { Position=position,Offset=offset,Size=size,Key=dataKey,TableKey=key,Header=header };
        }
        throw new IOException("Original Scripts path was not found in Game.rgss3a");
    }
    static byte[] Crypt(byte[] data, uint key) {
        byte[] result = new byte[data.Length];
        for (int i=0;i<data.Length;i++) {
            result[i] = (byte)(data[i] ^ (byte)(key >> ((i%4)*8)));
            if (i%4 == 3) key = unchecked(key*7+3);
        }
        return result;
    }
    static bool Equal(byte[] a, byte[] b) {
        if (a.Length != b.Length) return false;
        for (int i=0;i<a.Length;i++) if (a[i]!=b[i]) return false;
        return true;
    }
    static byte[] HashOriginalView(FileStream file,long length,long entry,byte[] original) {
        using (var sha = SHA256.Create()) {
            file.Position = 0;
            byte[] buffer = new byte[65536];
            long position=0;
            while (position<length) {
                int count = file.Read(buffer,0,(int)Math.Min(buffer.Length,length-position));
                if (count==0) throw new IOException("Truncated archive while verifying backup");
                for (int i=0;i<original.Length;i++)
                    if (entry+i>=position && entry+i<position+count) buffer[(int)(entry+i-position)]=original[i];
                sha.TransformBlock(buffer,0,count,buffer,0);
                position+=count;
            }
            sha.TransformFinalBlock(new byte[0],0,0);
            return sha.Hash;
        }
    }
    static string Journal(string folder) { return Path.Combine(folder,"archive-backup.bin"); }
    public static void Install(string archive,string scripts,string bootstrap,string folder) {
        byte[] payload = File.ReadAllBytes(bootstrap);
        Directory.CreateDirectory(folder);
        if (File.Exists(Journal(folder))) {
            using (var file = new FileStream(archive,FileMode.Open,FileAccess.Read,FileShare.Read)) {
                Entry current = Find(file,scripts);
                file.Position=current.Offset;
                byte[] decoded = Crypt(new BinaryReader(file).ReadBytes((int)current.Size),current.Key);
                if (Equal(decoded,payload)) return;
            }
            Restore(archive,folder);
        }
        using (var file = new FileStream(archive,FileMode.Open,FileAccess.ReadWrite,FileShare.Read)) {
            Entry entry = Find(file,scripts);
            long length = file.Length;
            if (length+payload.Length > UInt32.MaxValue) throw new IOException("RGSS3 archive would exceed its 4 GB limit");
            file.Position=entry.Offset;
            byte[] originalScripts = Crypt(Read(new BinaryReader(file),(int)entry.Size),entry.Key);
            if (originalScripts.Length<2 || originalScripts[0]!=4 || originalScripts[1]!=8)
                throw new IOException("Original scripts are not a Ruby Marshal archive");
            File.WriteAllBytes(Path.Combine(folder,"original_scripts.rvdata2"),originalScripts);
            byte[] originalHash = HashOriginalView(file,length,entry.Position,entry.Header);
            byte[] patched = (byte[])entry.Header.Clone();
            Array.Copy(BitConverter.GetBytes((uint)length^entry.TableKey),0,patched,0,4);
            Array.Copy(BitConverter.GetBytes((uint)payload.Length^entry.TableKey),0,patched,4,4);
            byte[] encrypted = Crypt(payload,entry.Key);
            using (var writer = new BinaryWriter(File.Create(Journal(folder)))) {
                writer.Write(Encoding.ASCII.GetBytes("VXCPATCH"));
                writer.Write(length); writer.Write(entry.Position);
                writer.Write(entry.Header); writer.Write(patched);
                writer.Write(encrypted.Length); writer.Write(originalHash);
            }
            try {
                // Append first; publish the new index entry only after flushing it.
                file.Position=length; file.Write(encrypted,0,encrypted.Length); file.Flush(true);
                file.Position=entry.Position; file.Write(patched,0,patched.Length); file.Flush(true);
            } catch {
                file.Position=entry.Position; file.Write(entry.Header,0,entry.Header.Length);
                file.SetLength(length); file.Flush(true);
                File.Delete(Journal(folder));
                throw;
            }
        }
    }
    public static void Restore(string archive,string folder) {
        if (!File.Exists(Journal(folder))) return;
        long length,position; byte[] original,patched,hash; int added;
        using (var reader = new BinaryReader(File.OpenRead(Journal(folder)))) {
            if (Encoding.ASCII.GetString(Read(reader,8))!="VXCPATCH") throw new IOException("Invalid archive backup journal");
            length=reader.ReadInt64(); position=reader.ReadInt64();
            original=Read(reader,16); patched=Read(reader,16); added=reader.ReadInt32(); hash=Read(reader,32);
        }
        using (var file = new FileStream(archive,FileMode.Open,FileAccess.ReadWrite,FileShare.Read)) {
            if (length<12 || position<12 || position+16>length || added<0 || file.Length<length || file.Length>length+added)
                throw new IOException("Archive size no longer matches this installation; refusing to overwrite changes");
            file.Position=position;
            byte[] current=Read(new BinaryReader(file),16);
            if (!Equal(current,original) && !Equal(current,patched)) throw new IOException("Archive index has changed since installation");
            if (!Equal(HashOriginalView(file,length,position,original),hash))
                throw new IOException("Archive content has changed since installation; original data was not modified");
            file.Position=position; file.Write(original,0,original.Length);
            file.SetLength(length); file.Flush(true);
        }
        File.Delete(Journal(folder));
    }
}
