require "digest"

class OsxfuseRequirement < Requirement
  fatal true

  satisfy(build_env: false) { self.class.binary_osxfuse_installed? }

  def self.binary_osxfuse_installed?
    File.exist?("/usr/local/include/fuse/fuse.h") &&
      !File.symlink?("/usr/local/include/fuse")
  end

  env do
    unless HOMEBREW_PREFIX.to_s == "/usr/local"
      ENV.append_path "HOMEBREW_LIBRARY_PATHS", "/usr/local/lib"
      ENV.append_path "HOMEBREW_INCLUDE_PATHS", "/usr/local/include/fuse"
    end
  end

  def message
    "macFUSE is required to build libguestfs. Please run `brew install --cask macfuse` first."
  end
end

class LibguestfsAT132 < Formula
  desc "Set of tools for accessing and modifying virtual machine (VM) disk images"
  homepage "https://libguestfs.org/"
  url "https://libguestfs.org/download/1.32-stable/libguestfs-1.32.6.tar.gz"

  depends_on "amar1729/libguestfs/automake-1.15" => :build
  depends_on "autoconf" => :build
  depends_on "libtool" => :build
  depends_on "pkg-config" => :build
  depends_on "coreutils" => :build
  depends_on "augeas"
  depends_on "cdrtools"
  depends_on "gettext"
  depends_on "glib"
  depends_on "libvirt"
  depends_on "pcre"
  depends_on "qemu"
  depends_on "readline"
  depends_on "xz"
  depends_on "yajl"

  on_macos do
    depends_on OsxfuseRequirement => :build
  end

  # the linux support is a bit of a guess, since homebrew doesn't currently build bottles for libvirt
  # that means brew test-bot's --build-bottle will fail under ubuntu-latest runners
  on_linux do
    depends_on "libfuse"
  end

  # Since we can't build an appliance, the recommended way is to download a fixed one.
  resource "fixed_appliance" do
    url "https://libguestfs.org/download/binaries/appliance/appliance-1.30.1.tar.xz"
    sha256 "12d88227de9921cc40949b1ca7bbfc2f6cd6e685fa6ed2be3f21fdef97661be2"
  end

  patch do
    # Change program_name to avoid collision with gnulib
    url "https://gist.github.com/zchee/2845dac68b8d71b6c1f5/raw/ade1096e057711ab50cf0310ceb9a19e176577d2/libguestfs-gnulib.patch"
    sha256 "b88e85895494d29e3a0f56ef23a90673660b61cc6fdf64ae7e5fecf79546fdd0"
  end

  patch do
    url "https://gist.githubusercontent.com/eberle1080/926664db3d15d2060eab3ae6faaa9b07/raw/dd91de60dab943626f80b1e33ef4b40a580c0b16/backing.patch"
  end

  patch do
    url "https://gist.githubusercontent.com/eberle1080/3e80549cb6d50f6f96e259fc61878e4b/raw/f3dd121604eb5983fa4d9848f52df23db09158d3/gistfile1.txt"
  end

  def install
    ENV["LIBTINFO_CFLAGS"] = "-I#{Formula["ncurses"].opt_include}"
    ENV["LIBTINFO_LIBS"] = "-lncurses"

    ENV["FUSE_CFLAGS"] = "-D_FILE_OFFSET_BITS=64 -D_DARWIN_USE_64_BIT_INODE -I/usr/local/include/osxfuse/fuse -I/usr/local/include/fuse"
    ENV["FUSE_LIBS"] = "-lfuse -pthread -liconv"

    ENV["AUGEAS_CFLAGS"] = "-I#{Formula["augeas"].opt_include}"
    ENV["AUGEAS_LIBS"] = "-L#{Formula["augeas"].opt_lib}"

    ENV["GTKDOCIZE"] = "echo"

    args = [
      "--disable-probes",
      "--disable-lua",
      "--disable-haskell",
      "--disable-erlang",
      "--disable-gtk-doc-html",
      "--disable-gobject",
      "--disable-php",
      "--disable-perl",
      "--disable-golang",
      "--disable-python",
      "--disable-ruby",
      "--disable-daemon",
      "--disable-appliance",
      "--disable-gnulib-tests",
    ]

    system "pwd"

    system "set"

    system "autoreconf", "-i"

    system "./configure", "--disable-dependency-tracking",
           "--disable-silent-rules",
           "--prefix=#{prefix}",
           *args

    system "make"

    ENV["REALLY_INSTALL"] = "yes"
    system "make", "install"

    libguestfs_path = "#{prefix}/var/libguestfs-appliance"
    mkdir_p libguestfs_path
    resource("fixed_appliance").stage(libguestfs_path)

    bin.install_symlink Dir["bin/*"]
  end

  def caveats
    <<~EOS
      A fixed appliance is required for libguestfs to work on Mac OS X.
      This formula downloads the appliance and places it in:
        #{prefix}/var/libguestfs-appliance

      To use the appliance, add the following to your shell configuration:
        export LIBGUESTFS_PATH=#{prefix}/var/libguestfs-appliance
      and use libguestfs binaries in the normal way.

      For compilers to find libguestfs you may need to set:
        export LDFLAGS="-L#{prefix}/lib"
        export CPPFLAGS="-I#{prefix}/include"

      For pkg-config to find libguestfs you may need to set:
        export PKG_CONFIG_PATH="#{prefix}/lib/pkgconfig"

    EOS
  end

  test do
    ENV["LIBGUESTFS_PATH"] = "#{prefix}/var/libguestfs-appliance"
    system "#{bin}/libguestfs-test-tool", "-t 180"
  end
end
