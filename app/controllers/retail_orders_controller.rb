class RetailOrdersController < ApplicationController
  before_action :authenticate_user!, except: [:api]
  before_action :set_retail_order, only: [:show, :edit, :update, :destroy]
  before_action :set_user, except: [:api, :customer]
  before_action :set_descriptions, only: [:new, :edit]
  before_action :set_names, only: [:customer]
  before_action :set_shiptos, only: [:shipto]

  # GET /retail_orders
  def index
    if @user == 'ADMIN'
      @retail_orders = RetailOrder.all
    else
      @retail_orders = RetailOrder.where(rep: @user).where.not(order_entered: true).where(status: "ACTIVE")
    end
    respond_to do |format|
      format.html
      format.csv { send_data @retail_orders.to_txt, :filename => 'orders.txt' }
    end
  end

  # GET /retail_orders/1
  def show
  end

  # GET /retail_orders/new
  def new
    @retail_order = RetailOrder.new
    @retail_order.customer = $customer
    @retail_order.shipto = $shipto
    @required_date = Time.current.tomorrow.strftime('%Y-%m-%d')
    20.times { @retail_order.retail_order_parts.build }
  end

  # GET /retail_orders/1/edit
  def edit
    # need to include any parts that have been added to this order that were not previously sold
    @required_date = @retail_order.date_required.strftime('%Y-%m-%d')
    parts = @retail_order.retail_order_parts.all
    parts.each do |p|
      if p.partdesc && !$descs.include?(p.partdesc)
        # include any new parts in description list
        jsdesc = p.partdesc.gsub(' ', '~')
        $descs.push(p.partdesc)
        $jsdescs.push(jsdesc)
      end
    end
    if @retail_order.retail_order_parts.count > 19
      @retail_order.retail_order_parts.build
    else
      i = 20 - @retail_order.retail_order_parts.count
      i.times { @retail_order.retail_order_parts.build }
    end

  end

  # POST /retail_orders
  def create
    fp = retail_order_params
    fp[:rep] = @user
    e = Employee.find_by(Badge_: @user)
    fp[:rep_name] = e.Firstname + ' ' + e.Lastname
    fp[:status] = 'ACTIVE'
    fp[:order_entered] = false
    cut_off_record = Lateorderscustomerco.find_by shipto_code: $shipto
    if cut_off_record
      fp[:cut_off] = cut_off_record.cutoff_time.strftime('%l:%M:%S %p')
    else
      fp[:cut_off] = "NO CUT OFF"
    end

    @retail_order = RetailOrder.new(fp)

    respond_to do |format|
      if @retail_order.save
        @retail_order.retail_order_parts.each do |p|
          if p.partdesc
            p.partdesc.gsub!('~', ' ')
          # need to store the part code for each descriptions
            part = Partmstr.find_by(part_desc: p.partdesc)
            if part
              if !p.partcode.blank?
                # if the partcode field is populated then a new part has been entered
                p.new_part = true
              else
                p.new_part = false
              end
              p.partcode = part.part_code
              p.save
            end
          end
        end
        format.html { redirect_to retail_orders_url, notice: 'Retail order was successfully created.' }
      else
        @retail_order.retail_order_parts.build
        @retail_order.retail_order_parts.each do |p|
          if p.partdesc && !$descs.include?(p.partdesc)
            # include any new parts in description list
            jsdesc = p.partdesc.gsub(' ', '~')
            $descs.push(p.partdesc)
            $jsdescs.push(jsdesc)
          end
        end
        format.html { render :new }
      end
    end
  end

  # PATCH/PUT /retail_orders/1
  def update
    fp = retail_order_params
    respond_to do |format|
      if @retail_order.update(fp)
        @retail_order.retail_order_parts.each do |p|
          if p.partdesc
          # need to store the part code for each descriptions
            part = Partmstr.find_by(part_desc: p.partdesc)
            if part
              p.partcode = part.part_code
              p.save
            end
          end
        end
        format.html { redirect_to retail_orders_url, notice: 'Retail order was successfully updated.' }
      else
        @retail_order.retail_order_parts.build
        @retail_order.retail_order_parts.each do |p|
          if p.partdesc && !$descs.include?(p.partdesc)
            # include any new parts in description list
            jsdesc = p.partdesc.gsub(' ', '~')
            $descs.push(p.partdesc)
            $jsdescs.push(jsdesc)
          end
        end
        format.html { render :edit }
      end
    end
  end

  # DELETE /retail_orders/1
  def destroy
    @retail_order.status = 'CANCELLED'
    @retail_order.cancel_rep = @user
    @retail_order.cancel_date = Date.today
    @retail_order.save
    respond_to do |format|
      format.html { redirect_to retail_orders_path, notice: 'Retail order was successfully cancelled.' }
    end
  end

  def customer
    if !user_signed_in? || !current_user.retail_order_input
      redirect_to signout_path and return
    end
  end

  def selected
    if params[:custname].blank?
      redirect_to retail_orders_customer_path, notice: 'No customer selected.'
    else
      bus_name = params[:custname].gsub(/[ ,]/, ' ' => '~', ',' => '`')
      i = $allnames.index(bus_name)
      $customer = $allcusts[i]
      default_shipto = ''
      shiptos = CustomerShipto.where(cust_code: $customer)
      if shiptos.length > 1
        # the user needs to pick a ship to
        redirect_to retail_orders_shipto_path
      else
        $shipto = $customer
        redirect_to action: "new"
      end
    end
  end

  def shipto
  end

  def chosen
    if params[:shipto].blank?
      redirect_to retail_orders_shipto_path, notice: 'No ship to selected.'
    else
      $shipto = params[:shipto]
      redirect_to action: "new"
    end
  end

  def error
    # find all the orders for the last 2 days with status 'ENTERED'
    if @user == 'ADMIN'
      @retail_orders = RetailOrder.where(order_entered: true).where("created_at >= ?", Date.today)
    else
      @retail_orders = RetailOrder.where(rep: @user).where(order_entered: true).where("created_at >= ?", Date.today)
    end
    @errors = []
    @retail_orders.each do |o|
      h = Ordhead.find_by order_numb: o.order_num
      if !h
        # an order was entered but the wrong order number was put into rapid order table
        error = { order_numb: o.order_num, error: 'Wrong order number from E21 was put into rapid orders' }
        @errors.push(error)
      else
        if h.order_date != o.date_required
          error = { order_numb: o.order_num, error: 'E21 date ('+h.order_date.strftime("%e %b %Y")+') does not match rapid order date ('+o.date_required.strftime("%e %b %Y")+').' }
          @errors.push(error)
        end
        if h.cust_code != o.customer
          error = { order_numb: o.order_num, error: 'E21 customer ('+h.cust_code+') does not match rapid order customer ('+o.customer+').' }
          @errors.push(error)
        end
        if h.shipto_code != o.shipto
          error = { order_numb: o.order_num, error: 'E21 shipto ('+h.shipto_code+') does not match rapid order shipto ('+o.shipto+').' }
          @errors.push(error)
        end
        if (h.cust_po != o.po_number) && (!h.cust_po.blank? || !o.po_number.blank?)
          error = { order_numb: o.order_num, error: 'E21 PO ('+h.cust_po.to_s+') does not match rapid order PO ('+o.po_number.to_s+').' }
          @errors.push(error)
        end
        # find discrepancies in parts between E21 and rapid order
        items = Orditem.where(order_numb: o.order_num)
        parts = o.retail_order_parts.all
        e21_parts = []
        items.each do |i|
          e21_parts.push(i.part_code)
          parts.each do |p|
            if i.part_code == p.partcode
              if i.qty != p.qty
                error = { order_numb: o.order_num, error: 'Part ('+i.part_code+') E21 quantity ('+i.qty.to_s+') does not match rapid order quantity ('+p.qty.to_s+').' }
                @errors.push(error)
              end
            end
          end
        end
        roe_parts = []
        parts.each do |p|
          roe_parts.push(p.partcode)
        end
        e21_parts.each do |e|
          if !roe_parts.include?(e)
            # e21 has a part not in the ROE data
            error = { order_numb: o.order_num, error: 'E21 part ('+e+') is not in the rapid order.' }
            @errors.push(error)
          end
        end
        roe_parts.each do |r|
          if !e21_parts.include?(r)
            # ROE has a part not in the e21 data
            error = { order_numb: o.order_num, error: 'Rapid order part ('+r+') is not in the E21 order.' }
            @errors.push(error)
          end
        end
      end
    end

  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_retail_order
      @retail_order = RetailOrder.find(params[:id])
      $customer = @retail_order.customer
    end

    def set_user
      @user = current_user.email.upcase
    end

    def set_descriptions
      if !$alldescs
        # need to set up global list of part descriptions
        parts = Partmstr.all
        # parts = Partmstr.where(part_status: 'A')
        sort_array = []
        $alldescs = []
        $allcodes = []
        $alluoms = []
        food_parts = ["ALL", "DRY", "FRE", "FRZ", "MUS"]
        unwanted_uom = ["ST", "LB"]
        $allcodes.push(' ')
        $alluoms.push(' ')
        $alldescs.push(' ')
        parts.each do |p|
          if !p.part_code.blank? && !p.part_desc.start_with?("INACTIVE") && food_parts.include?(p.storage_type) && p.part_status == "A" && !unwanted_uom.include?(p.uom)
            desc = p.part_desc.gsub(' ', '~')
            if p.part_code[0,1] == 'Z'
              # frozen codes should sort to the bottom of the list
              desc.insert(0,'Z')
            end
            combined = desc + p.part_code + desc.length.to_s + p.uom
            sort_array.push(combined)
          end
        end
        sorted_array = sort_array.sort
        sorted_array.each do |p|
          uom = p[p.length-2,2]
          desc_len = p[p.length-4,2]
          desc_length = desc_len.to_i
          des = p[0,desc_length]
          offset = desc_length
          code_length = p.length - (desc_length + 4)
          code = p[offset,code_length]
          if des[0,1] == 'Z'
            desc = des[1..-1]
          else
            desc = des
          end
          $allcodes.push(code)
          $alluoms.push(uom)
          $alldescs.push(desc)
        end
      end
      if !$old_customer || $old_customer != $customer || $old_shipto != $shipto
        sort_array = []
        # get the parts for the customer if the ship to is the same, else get the parts for the ship to
        parts = Oecusbuy.where(cust_code: $shipto).where(last_ship_date: 30.days.ago..Date.today)
        old_parts = Oecusbuy.where(cust_code: $shipto).where(last_ship_date: 394.days.ago..334.days.ago)
        $old_customer = $customer
        $old_shipto = $shipto
        $descs = []
        $jsdescs = []
        $jsuoms = []
        $jsdescs.push('~')
        $descs.push(' ')
        $jsuoms.push('~')
        if parts.length > 0
          desc = 'Y*** RECENTLY ORDERED ***'
          combined = desc + 'AAAAAAAAA' + desc.length.to_s + 'AA'
          sort_array.push(combined)
        end
        parts.each do |p|
          if p.part_code
            part = Partmstr.find_by(part_code: p.part_code)
            if part
              desc = part.part_desc.gsub(' ', '~')
              desc.insert(0,'Y')
              if part.part_code[0,1] == 'Z'
                # frozen codes should sort to the bottom of the list
                desc.insert(1,'Z')
              end
              combined = desc + p.part_code + desc.length.to_s + p.uom
              sort_array.push(combined)
            end
          end
        end
        if old_parts.length > 0
          desc = 'Z*** ORDERED THIS TIME LAST YEAR ***'
          combined = desc + 'AAAAAAAAA' + desc.length.to_s + 'AA'
          sort_array.push(combined)
        end
        old_parts.each do |p|
          if p.part_code
            part = Partmstr.find_by(part_code: p.part_code)
            if part
              desc = part.part_desc.gsub(' ', '~')
              desc.insert(0,'Z')
              if part.part_code[0,1] == 'Z'
                # frozen codes should sort to the bottom of the list
                desc.insert(1,'Z')
              end
              combined = desc + p.part_code + desc.length.to_s + p.uom
              sort_array.push(combined)
            end
          end
        end
        sorted_array = sort_array.sort
        sorted_array.each do |p|
          uom = p[p.length-2,2]
          desc_len = p[p.length-4,2]
          desc_length = desc_len.to_i
          des = p[0,desc_length]
          offset = desc_length
          code_length = p.length - (desc_length + 4)
          code = p[offset,code_length]
          if des[0,2] == 'ZZ' || des[0,2] == 'YZ' || des[0,2] == 'XZ'
            desc = des[2..-1]
          else
            desc = des[1..-1]
          end
          $jsdescs.push(desc.gsub(' ', '~'))
          desc.gsub!('~', ' ')
          if !$descs.include?(desc)
            $descs.push(desc)
          end
          $jsuoms.push(uom)
        end
      end
    end

    def set_names
    # need to set up global list of customers
      sort_array = []
      shiptos = []
      $allcusts = []
      $allnames = []
      $names = []
      if current_user.retail_order_input_rep1
        shiptos = CustomerShipto.where(acct_manager: current_user.retail_order_input_rep1)
        if current_user.retail_order_input_rep2
          shiptos2 = CustomerShipto.where(acct_manager: current_user.retail_order_input_rep2)
          shiptos += shiptos2
        end
      end
      shiptos.each do |s|
        # some customer have short names. Adding 10 makes sure the name length is double digits
        length = s.bus_name.length + 10
        combined = s.bus_name + s.cust_code + length.to_s
        if !sort_array.include?(combined)
          sort_array.push(combined)
        end
      end
      sort_array.sort!
      sort_array.each do |p|
        name_len = p[p.length-2,2]
        name_length = name_len.to_i - 10
        bus_name = p[0,name_length]
        offset = name_length
        cust_length = p.length - (name_length + 2)
        cust = p[offset,cust_length]
        $names.push(bus_name)
        $allcusts.push(cust.gsub(' ', '~'))
        $allnames.push(bus_name.gsub(/[ ,]/, ' ' => '~', ',' => '`'))
      end
    end

    def set_shiptos
      @shiptos = []
      default_shipto = ''
      shiptos = CustomerShipto.where(cust_code: $customer)
      shiptos.each do |s|
        if s.default_flag == '1'
          default_shipto = s.shipto_code
        else
          @shiptos.push(s.shipto_code)
        end
      end
      @shiptos.sort!
      if !default_shipto.blank?
        @shiptos.insert(0, default_shipto)
      end
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def retail_order_params
      params.require(:retail_order).permit(
        :customer, :shipto, :date_required, :rep, :status, :cancel_rep, :cancel_date, :po_number, :notes, :order_entered, :second_run, :rep_name, :cut_off,
        retail_order_parts_attributes: [
          :id,
          :partcode,
          :qty,
          :partdesc,
          :uom,
          :new_part
        ]
      )
    end
end
