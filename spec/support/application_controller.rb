class ApplicationController
  def params
    @params ||={}
  end

  def update_params(p)
    @params = p
  end
end