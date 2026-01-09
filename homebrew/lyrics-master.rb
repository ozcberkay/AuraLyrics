class LyricsMaster < Formula
  desc "Minimalist, Always-on-Top Spotify Lyrics for macOS"
  homepage "https://github.com/YOUR_USERNAME/LyricsMaster"
  url "https://github.com/YOUR_USERNAME/LyricsMaster/releases/download/v1.0.0/LyricsMaster.tar.gz"
  sha256 "REPLACE_WITH_SHA256_FROM_BUILD_SCRIPT"
  version "1.0.0"

  depends_on :macos

  def install
    # Install the .app bundle to the prefix
    prefix.install "LyricsMaster.app"
    
    # Create a wrapper script in bin to launch it easily
    # Note: "open -a" is better for .app bundles than calling binary directly for proper bundle resolution
    (bin/"lyrics-master").write <<~EOS
      #!/bin/bash
      open "#{prefix}/LyricsMaster.app"
    EOS
  end

  test do
    system "#{bin}/lyrics-master", "--help"
  end
end
