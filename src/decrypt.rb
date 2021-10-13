require 'zlib'
require_relative 'pack_rgss/rgss_encryptor'

encryptor = RgssEncryptor.new
files = encryptor.decrypt('Scripts.rgssad')

scripts = Marshal.load(files[0].file)
puts Zlib::Inflate.inflate(scripts[0][2]).force_encoding('utf-8')
