class String
  #def  "\033[0mAll attributes off\033[0m\n"
  def ascii_bold; "\033[1m#{self}\033[0m\n"; end
  def ascii_underline;  "\033[4m#{self}\033[0m\n"; end
  def ascii_blink;  "\033[5m#{self}\033[0m\n"; end
  def ascii_hide;  "\033[8m#{self}\033[0m\n"; end
  def ascii_black;  "\033[30m#{self}\033[0m\n"; end
  def ascii_red;  "\033[31m#{self}\033[0m\n"; end
  def ascii_green;  "\033[32m#{self}\033[0m\n"; end
  def ascii_yellow;  "\033[33m#{self}\033[0m\n"; end
  def ascii_blue;  "\033[34m#{self}\033[0m\n"; end
  def ascii_magenta;  "\033[35m#{self}\033[0m\n"; end
  def ascii_cyan;  "\033[36m#{self}\033[0m\n"; end
  def ascii_white;  "\033[37m#{self}\033[0m\n"; end
  def ascii_black_bg;  "\033[40m\033[37m#{self}\033[0m\n"; end
  def ascii_red_bg;  "\033[41m#{self}\033[0m\n"; end
  def ascii_green_bg;  "\033[42m#{self}\033[0m\n"; end
  def ascii_yellow_bg;  "\033[43m#{self}\033[0m\n"; end
  def ascii_blue_bg;  "\033[44m#{self}\033[0m\n"; end
  def ascii_magenta_bg;  "\033[45m#{self}\033[0m\n"; end
  def ascii_cyan_bg;  "\033[46m#{self}\033[0m\n"; end
  def ascii_white_bg;  "\033[47m#{self}\033[0m\n"; end
end