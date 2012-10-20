
# https://bitbucket.org/ged/ruby-axis/raw/ef212387adcbd567a39fa0d51eb6dc6051c416bf/lib/axis/monkeypatches.rb

# Backport of Ruby 1.9.2 URI methods to 1.8.7.
module URIFormEncoding

    TBLENCWWWCOMP_ = {} # :nodoc:
    TBLDECWWWCOMP_ = {} # :nodoc:


    # Encode given +str+ to URL-encoded form data.
    #
    # This doesn't convert *, -, ., 0-9, A-Z, _, a-z,
    # does convert SP to +, and convert others to %XX.
    #
    # This refers http://www.w3.org/TR/html5/forms.html#url-encoded-form-data
    #
    # See URI.decode_www_form_component, URI.encode_www_form
    def encode_www_form_component( str )
        if TBLENCWWWCOMP_.empty?
            256.times do |i|
                TBLENCWWWCOMP_[i.chr] = '%%%02X' % i
            end
            TBLENCWWWCOMP_[' '] = '+'
            TBLENCWWWCOMP_.freeze
        end
        return str.to_s.gsub(/[^*\-.0-9A-Z_a-z]/, TBLENCWWWCOMP_)
    end

    # Decode given +str+ of URL-encoded form data.
    #
    # This decodes + to SP.
    #
    # See URI.encode_www_form_component, URI.decode_www_form
    def decode_www_form_component( str )
        if TBLDECWWWCOMP_.empty?
            256.times do |i|
                h, l = i>>4, i&15
                TBLDECWWWCOMP_['%%%X%X' % [h, l]] = i.chr
                TBLDECWWWCOMP_['%%%x%X' % [h, l]] = i.chr
                TBLDECWWWCOMP_['%%%X%x' % [h, l]] = i.chr
                TBLDECWWWCOMP_['%%%x%x' % [h, l]] = i.chr
            end
            TBLDECWWWCOMP_['+'] = ' '
            TBLDECWWWCOMP_.freeze
        end
        raise ArgumentError, "invalid %-encoding (#{str})" unless /\A(?:%\h\h|[^%]+)*\z/ =~ str
        return str.gsub( /\+|%\h\h/, TBLDECWWWCOMP_ )
    end

    # Generate URL-encoded form data from given +enum+.
    #
    # This generates application/x-www-form-urlencoded data defined in HTML5
    # from given an Enumerable object.
    #
    # This internally uses URI.encode_www_form_component(str).
    #
    # This doesn't convert encodings of give items, so convert them before call
    # this method if you want to send data as other than original encoding or
    # mixed encoding data. (strings which is encoded in HTML5 ASCII incompatible
    # encoding is converted to UTF-8)
    #
    # This doesn't treat files. When you send a file, use multipart/form-data.
    #
    # This refers http://www.w3.org/TR/html5/forms.html#url-encoded-form-data
    #
    # See URI.encode_www_form_component, URI.decode_www_form
    def encode_www_form( enum )
        str = nil
        enum.each do |k,v|
            if str
                str << '&'
            else
                str = nil.to_s
            end
            str << encode_www_form_component(k)
            str << '='
            str << encode_www_form_component(v)
        end
        str
    end

    WFKV_ = '(?:%\h\h|[^%#=;&])' # :nodoc:

    # Decode URL-encoded form data from given +str+.
    #
    # This decodes application/x-www-form-urlencoded data
    # and returns array of key-value array.
    # This internally uses URI.decode_www_form_component.
    #
    # This refers http://www.w3.org/TR/html5/forms.html#url-encoded-form-data
    #
    # ary = URI.decode_www_form("a=1&a=2&b=3")
    # p ary                  #=> [['a', '1'], ['a', '2'], ['b', '3']]
    # p ary.assoc('a').last  #=> '1'
    # p ary.assoc('b').last  #=> '3'
    # p ary.rassoc('a').last #=> '2'
    # p Hash[ary]            # => {"a"=>"2", "b"=>"3"}
    #
    # See URI.decode_www_form_component, URI.encode_www_form
    def decode_www_form( str )
        return [] if str.empty?
        unless /\A#{WFKV_}*=#{WFKV_}*(?:[;&]#{WFKV_}*=#{WFKV_}*)*\z/o =~ str
            raise ArgumentError, "invalid data of application/x-www-form-urlencoded (#{str})"
        end
        ary = []
        $&.scan(/([^=;&]+)=([^;&]*)/) do
            ary << [decode_www_form_component($1, enc), decode_www_form_component($2, enc)]
        end
        ary
    end

end


unless URI.methods.include?( :encode_www_form )
    URI.extend( URIFormEncoding )
end


