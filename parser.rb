# Given a .tsv file generated from the floor locations spreadsheet at
# https://docs.google.com/spreadsheets/d/1s3JFOcEYbM8weSmy16u9DQIEC6EHRWMmzWnZCSE0EWA/edit
# ...generate a .json file with computed start/stop keys

# Usage: 
#
# ruby parser.rb inputfile.tsv > floor_locations.json

require 'json'
require 'pry'

filename = ARGV[0]

module CNRange
  attr_accessor :str
  attr_reader :start, :stop
  
  def initialize(cnrange = nil)
    @str = cnrange
    if cnrange
      start,stop = cnrange.strip.split /\s*-\s*/
      raise ArgumentError.new(cnrange) unless self.matches(start)
      self.set_range(start,stop)
    end
  end
  
  def set_range(rawstart, rawstop)
    self.start = rawstart
    if rawstop
      self.stop = rawstop
    else
      self.stop = rawstart
    end
  end
  
  def start=(cn)
    @start = start_of_range(cn)
  end
  
  def stop=(cn)
    @stop = end_of_range(cn)
  end
  
  def matches(cnr)
    @matcher.match(cnr.strip.downcase)
  end
  
end


class LCRange 
  include CNRange
  
  LCNMATCH = /\A([a-z]+)(\d+)?(.*)\Z/
  CHAR_THAT_SORTS_LAST = 'z'

  

  def initialize(cnr)
    @matcher = LCNMATCH
    super
  end
  
  def normalize(cn)
    cn = cn.downcase.gsub(/[\s\.]/, '')
    m = LCNMATCH.match(cn)
    letters, numbers, rest = m[1], m[2], m[3]

    return letters unless "#{numbers}#{rest}" =~ /\S/

    numbers = 0 if numbers.nil? or numbers.empty?
    "%s%05d%s" % [letters, numbers, rest]
  end
  
  
  def start_of_range(cn)
    normalize(cn)
  end
  
  def end_of_range(cn)
    normalize(cn) +  CHAR_THAT_SORTS_LAST
  end
  
  
end

class DeweyRange
  
  include CNRange
  
  DEWEYMATCHER = /\A([\d\.]+)\Z/
  
  def initialize(cnr)
    @matcher = DEWEYMATCHER
    super
  end
  
  def normalize(cn)
    Float(cn)
  end
  
  def start_of_range(rawstart)
    normalize rawstart
  end
  
  def end_of_range(rawstop)
    eafs = normalize(rawstop).to_s
    eafs += '.' unless eafs =~ /\./
    Float(eafs + '9999')
  end
end

  

class CallNumberMap
  
  attr_accessor :library,  :text, :floor_key
  attr_reader :collection
  
  
  def initialize(library, collection, callnumber_range, floor_key, text)
    self.library = library
    self.collection = collection 
    self.callnumber_range = callnumber_range if callnumber_range
    self.floor_key = floor_key
    self.text = text
  end
  
  def collection=(coll)
    if coll.upcase.strip =~ /\A[A-Z]+\Z/
      @collection = coll.upcase.strip
    else
      @collection = nil
    end
  end
  
  def callnumber_range
    "#{@start} - #{@stop}"
  end
    
  def callnumber_range=(cnrange)
    begin
      cnr = LCRange.new(cnrange)
      @type = 'LC'
    rescue ArgumentError => e
      cnr = DeweyRange.new(cnrange)
      @type = "Dewey"
    end
    @start = cnr.start
    @stop  = cnr.stop
  end
    
  def include?(cn)
    ncn = normalize(cn)
    @start <= ncn and ncn < @stop
  end
  
  def to_h
    {
      'library' => library,
      'collection' => collection,
      'start' => @start,
      'stop' => @stop,
      'floor_key' => floor_key,
      'text' => text,
      'type' => @type
    }
  end
  
  def as_json
    to_h
  end
  
  def to_json(*a)
    as_json.to_json(*a)
  end
    
end

class SublibMap < CallNumberMap
  def initialize(lib,coll,floor_key,text)
    @type = "Everything"
    super(lib,coll,nil,floor_key, text)
  end
  
  def include?(cn)
    true
  end
  
  def to_h
    {
      'library' => library,
      'collection' => collection,
      'floor_key' => floor_key,
      'text' => text,
      'type' => @type
    }
  end
  
end
  

h = {}
File.open(filename, 'r:utf-8') do |f|
  f.gets # skip a line for the headers
  f.each_line do |rawline|
    next unless rawline =~ /\S/
    (lib, coll, cnrange, _, _, floor_key, text) = rawline.chomp.split(/\t/)
    coll = '' if coll == '(none)'
    h[lib] ||= {}
    h[lib][coll] ||= []
    if cnrange =~ /\S/
      h[lib][coll] <<  CallNumberMap.new(lib.upcase, coll.upcase, cnrange, floor_key, text)
    else
      h[lib][coll] << SublibMap.new(lib.upcase, coll.upcase, floor_key, text)
    end
  end
end

puts h.to_json



  
  
