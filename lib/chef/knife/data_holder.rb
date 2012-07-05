require 'pp'

class DataHolder

  def initialize
    @holder = {}
    @path = nil
  end

  def method_missing(name, *args)
    @holder[name] = args
  end

  def ==(holder)
    raise TypeError.new('Comparisons only allowed between DataHolder instances')
    self._holder == holder._holder
  end

  def _holder
    @holder
  end

  def _load(path)
    @path = path
    self.instance_eval(
      File.read(path)
    )
    self
  end

  def _output
    output = ''
    @holder.each_pair do |k,v|
      output << "#{k}(\n"
      inards = []
      v.each do |item|
        s = ''
        PP.pp(item, s)
        inards << s
      end
      output << inards.join(",\n")
      output << ")\n"
    end
    output
    File.open(@path, 'w') do |file|
      file.write(output)
    end
    output
  end

  def _path
    @path
  end
end
