require_relative 'lib/konfipay'

Konfipay.config do |c|
  c.api_key = 'xdpNY0RGiGudG7U08o1T46SyIL2Ypi19gPUN2SBtLcypBju6yB72EIw37I9jdpNw'
end

Konfipay::Connection.new
puts Konfipay.api_key
