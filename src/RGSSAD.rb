module RGSSAD

  @@files = []
  @@xor = 0xDEADCAFE
  @@NEXT = 0
  #ENC_FILE = Dir["Game.rgss{ad,2a}"][0] || ""
  RGSSAD_File = Struct.new('RGSSAD_File', :filename, :filename_size, :file, :file_size)

  public

  def self.decrypt(filename)
    return unless File.exists?(filename)
    @@files.clear
    rgssad = ''
    File.open(filename, 'rb') {|file|
      file.read(8)
      rgssad = file.read
    }
    rgssad = self.parse_rgssad(rgssad, true)
    offset = 0
    while rgssad[offset] != nil
      file = RGSSAD_File.new
      file.filename_size = rgssad[offset, 4].unpack('L')[0]
      offset += 4
      file.filename = rgssad[offset, file.filename_size]
      offset += file.filename_size
      file.file_size = rgssad[offset, 4].unpack('L')[0]
      offset += 4
      file.file = rgssad[offset, file.file_size]
      @@files << file
      offset += file.file_size
    end
    return @@files
  end
  
  def self.files
    @@files
  end

  def self.add_file(file_contents, filename)
    file = RGSSAD_File.new
    file.filename = filename
    file.filename_size = filename.size
    file.file = file_contents
    file.file_size = file_contents.size
    @@files.delete_if {|f| f.filename == file.filename}
    @@files << file
    @@files.sort! {|a,b| a.filename <=> b.filename}
  end

  def self.encrypt(filename)
    return if @@files.empty? && !File.exists?(filename)
    rgssad = ''
    @@files.each do |file|
      rgssad << [file.filename_size].pack('L')
      rgssad << file.filename
      rgssad << [file.file_size].pack('L')
      rgssad << file.file
    end
    File.open(filename, 'wb') do |file|
      file.print("RGSSAD\0\1")
      file.print(self.parse_rgssad(rgssad, false))
    end
  end

  private

  def self.next_key
    @@xor = (@@xor * 7 + 3) & 0xFFFFFFFF
    @@NEXT += 1
  end
  
  def self.parse_rgssad(string, decrypt)
    @@xor = 0xDEADCAFE
    new_string = ''
    offset = 0
    remember_offsets = []
    remember_keys = []
    remember_size = []
    while string[offset] != nil
      namesize = string[offset, 4].unpack('L')[0]
      new_string << [namesize ^ @@xor].pack('L')
      namesize ^= @@xor if decrypt
      offset += 4
#p @@NEXT,@@xor if @@NEXT > 330
      self.next_key
      filename = string[offset, namesize]
      namesize.times do |i|
        filename[i] = filename[i] ^ @@xor & 0xFF
        #filename.setbyte(i, filename.getbyte(i) ^ @@xor & 0xFF)
        self.next_key
      end
      new_string << filename
      offset += namesize
      datasize = string[offset, 4].unpack('L')[0]
      new_string << [datasize ^ @@xor].pack('L')
      datasize ^= @@xor if decrypt
      remember_size << datasize
      offset += 4
      self.next_key

      data = string[offset, datasize]
      new_string << data
      remember_offsets << offset
      remember_keys << @@xor
      offset += datasize
#p namesize,datasize,@@xor
    end
    remember_offsets.size.times do |i|
      offset = remember_offsets[i]
      @@xor = remember_keys[i]
      size = remember_size[i]
      data = new_string[offset, size]
      data = data.ljust(size + (4 - size % 4)) if size % 4 != 0
      s = ''
a = false
      data.unpack('L' * (data.size / 4)).each do |j|
if a == false
  a = true
  p @@NEXT,@@xor,j , j ^ @@xor,"@@NEXT,@@xor,j , j ^ @@xor"
end
        s << ([j ^ @@xor].pack('L'))
        self.next_key
      end
      new_string[offset, size] = s.slice(0, size)
    end
exit
    return new_string
  end
end











def mkdir_p(path)
  path_arr = File.dirname(path).split("\\")
  #path_arr = path.split("\\")[0...-1]
  path = ""
  for name in path_arr
    path << name
    path << "\\"
    next if File.directory?(path)
    Dir::mkdir(path)
  end
end
#files = RGSSAD.decrypt("Game.rgss3a","output/")
files = RGSSAD.decrypt("Game34.rgssad")
p files
for file in files
  path = "output\\#{file.filename}"
  mkdir_p(path)
  File.open(path,"wb"){|f|
    f.write(file.file)
  }
end
