module Pdf
  module DaySheet

    def generate_collection_pdf(date)
      folder   = File.join(Merb.root, "doc", "pdfs", "staff", self.name, "collection_sheets")
      FileUtils.mkdir_p(folder)
      filename = File.join(folder, "collection_#{self.id}_#{date.strftime('%Y_%m_%d')}.pdf")
      center_ids = LoanHistory.all(:date => [date, date.holidays_shifted_today].uniq, :fields => [:loan_id, :date, :center_id], :status => [:disbursed, :outstanding]).map{|x| x.center_id}.uniq
      centers = self.centers(:id => center_ids).sort_by{|x| x.name}
      pdf = PDF::Writer.new(:orientation => :landscape, :paper => "A4")
      pdf.select_font "Times-Roman"
      pdf.text "Daily Collection Sheet for #{self.name} for #{date}", :font_size => 24, :justification => :center
      pdf.text("\n")
      return nil if centers.empty?
      days_absent = Attendance.all(:status => "absent", :center => centers).aggregate(:client_id, :all.count).to_hash 
      days_present = Attendance.all(:center => centers).aggregate(:client_id, :all.count).to_hash
      centers.sort_by{|x| x.meeting_time_hours*60 + x.meeting_time_minutes}.each_with_index{|center, idx|
        pdf.start_new_page if idx > 0
        pdf.text "Center: #{center.name}, Manager: #{self.name}, signature: ______________________", :font_size => 12, :justification => :left
        pdf.text("Center leader: #{center.leader.client.name}, signature: ______________________", :font_size => 12, :justification => :left) if center.leader
        pdf.text("Date: #{date}, Time: #{center.meeting_time_hours}:#{'%02d' % center.meeting_time_minutes}", :font_size => 12, :justification => :left)
        pdf.text("\n")
        table = PDF::SimpleTable.new
        table.data = []
        tot_amount, tot_outstanding, tot_installments, tot_principal, tot_interest, total_due, tot_installment_amount = 0, 0, 0, 0, 0, 0, 0
        #Prefecth some data for speed
        loans = center.loans
        puts "#{center.name} : #{loans.aggregate(:id)}"
        histories = LoanHistory.all(:loan_id => loans.map{|x| x.id}, :date => date)
        fees_applicable = Fee.due(loans.map{|x| x.id})
        tot_amount, tot_outstanding, tot_installments, tot_principal, tot_interest, tot_fee, tot_total = 0, 0, 0, 0, 0, 0, 0

        #grouping by client groups
        center.clients(:fields => [:id, :name]).group_by{|x| x.client_group}.sort_by{|x| x[0] ? x[0].name : "none"}.each{|group, clients|
          group_amount, group_outstanding, group_installments, group_principal, group_interest, group_fee, group_due, group_installment_amount = 0, 0, 0, 0, 0, 0, 0, 0
          table.data.push({"disbursed" => group ? group.name : "No group"})
          #absent days
          #Grouped clients
          clients.sort_by{|x| x.name}.each{|client|
            # all the loans of a client
            loan_row_count=0
            loans.find_all{|l| l.client_id==client.id and l.disbursal_date}.each{|loan|
              lh = histories.find_all{|x| x.loan_id==loan.id}.sort_by{|x| x.created_at}[-1]
              next if not lh
              next if LOANS_NOT_PAYABLE.include? lh.status
              loan_row_count+=1
              fee = fees_applicable[loan.id] ? fees_applicable[loan.id].due : 0
              actual_outstanding = (lh ? lh.actual_outstanding_principal : 0)
              principal_due      = [(lh ? lh.principal_due : 0), 0].max
              interest_due       = [(lh ? lh.interest_due : 0), 0].max
              total_due          = [(lh ? (fee+lh.principal_due+lh.interest_due): 0), 0].max
              installment_number = loan.installment_for_date(date)
              installment_amount = loan.scheduled_principal_for_installment(installment_number) + loan.scheduled_interest_for_installment(installment_number)
              
              table.data.push({"name" => client.name, "loan id" => loan.id, "amount" => loan.amount.to_currency, 
                                "outstanding" => actual_outstanding.to_currency, "installment" =>  installment_number,
                                "installment amount" => installment_amount,
                                "total due" =>  total_due.to_currency, "collected amount" => "", "signature" => "" })
              group_amount       += loan.amount
              group_outstanding  += actual_outstanding
              group_installments += installment_number
              group_principal    += principal_due
              group_interest     += interest_due
              group_fee          += fee
              group_due          += total_due
              group_installment_amount += installment_amount
            } # loans end
            if loan_row_count==0
              table.data.push({"name" => client.name, "signature" => "", "status" => "nothing outstanding"})              
            end
          } #clients end
          table.data.push({"amount" => group_amount.to_currency, "outstanding" => group_outstanding.to_currency,
                            "installment amount" => group_installment_amount.to_currency, "total due" => group_due.to_currency
                          })
          tot_amount         += group_amount
          tot_outstanding    += group_outstanding
          tot_installments   += group_installments
          tot_principal      += group_principal
          tot_interest       += group_interest
          tot_fee            += group_fee
          total_due          += (group_principal + group_interest + group_fee)
          tot_installment_amount += group_installment_amount
        } #groups end
        table.data.push({"amount" => tot_amount.to_currency, "outstanding" => tot_outstanding.to_currency,
                          "installment amount" => tot_installment_amount.to_currency, 
                          "total due" => (tot_principal + tot_interest + tot_fee).to_currency
                        })

        debugger
        table.column_order  = ["name", "loan id" , "amount", "outstanding", "installment amount" ,"installment", "total due", "collected amount", "signature"]
        table.show_lines    = :all
        table.show_headings = true
        table.shade_rows    = :none
        table.shade_headings = true
        table.orientation   = :center
        table.position      = :center
        table.title_font_size = 16
        table.header_gap = 10
        table.render_on(pdf)
        
        #draw table for scheduled disbursals
        loans_to_disburse = center.clients.loans(:scheduled_disbursal_date => date)
        if center.clients.count>0 and loans_to_disburse.count > 0
          table = PDF::SimpleTable.new
          table.data = []

          loans_to_disburse.each do |loan|
            table.data.push({"amount" => loan.amount.to_currency, "name" => loan.client.name,
                              "group" => loan.client.client_group.name,
                              "loan product" => loan.loan_product.name, "first payment" => loan.scheduled_first_payment_date                              ,"spouse name" => loan.client.spouse_name 
                            })
          end
          table.column_order  = ["name", "spouse name", "group", "amount", "loan product", "first payment", "signature"]
          table.show_lines    = :all
          table.shade_rows    = :none
          table.show_headings = true          
          table.shade_headings = true
          table.orientation   = :center
          table.position      = :center
          table.title_font_size = 16
          table.header_gap = 10
          pdf.text("\n")
          pdf.text "Disbursements today"
          pdf.text("\n")
          table.render_on(pdf)
        end        
      } #centers end
      pdf.save_as(filename)
      return pdf
    end

    def generate_disbursement_pdf(date)
      folder   = File.join(Merb.root, "doc", "pdfs", "staff", self.name, "disbursement_sheets")
      FileUtils.mkdir_p(folder)
      filename = File.join(folder, "disbursement_#{self.id}_#{date.strftime('%Y_%m_%d')}.pdf")
      center_ids = Loan.all(:scheduled_disbursal_date => date, :approved_on.not => nil, :rejected_on => nil).map{|x| x.client.center_id}.uniq
      centers = self.centers(:id => center_ids).sort_by{|x| x.name}

      pdf = PDF::Writer.new(:orientation => :landscape, :paper => "A4")
      pdf.select_font "Times-Roman"
      pdf.text "Daily Disbursement Sheet for #{self.name} for #{date}", :font_size => 24, :justification => :center
      pdf.text("\n")
      return nil if centers.empty?   
      days_absent = Attendance.all(:status => "absent", :center => centers).aggregate(:client_id, :all.count).to_hash
      centers.sort_by{|x| x.meeting_time_hours*60 + x.meeting_time_minutes}.each_with_index{|center, idx|
        pdf.start_new_page if idx > 0
        pdf.text "Center: #{center.name}, Manager: #{self.name}, signature: ______________________", :font_size => 12, :justification => :left
        pdf.text("Center leader: #{center.leader.client.name}, signature: ______________________", :font_size => 12, :justification => :left) if center.leader
        pdf.text("Date: #{date}, Time: #{center.meeting_time_hours}:#{'%02d' % center.meeting_time_minutes}", :font_size => 12, :justification => :left)
        pdf.text("Actual Disbursement on ___________________________, signature: ______________________", :font_size => 12, :justification => :left)
        pdf.text("\n")
        #draw table for scheduled disbursals
        loans_to_disburse = center.clients.loans(:scheduled_disbursal_date => date) #, :disbursal_date => nil, :approved_on.not => nil, :rejected_on => nil)
        if center.clients.count>0 and loans_to_disburse.count > 0
          table = PDF::SimpleTable.new
          table.data = []
          tot_amount = 0
          loans_to_disburse.each do |loan|
            tot_amount += loan.amount
            premia, amount_to_disburse = 0, nil
            debugger
            if loan.loan_product.linked_to_insurance and loan.insurance_policy
              premia = loan.insurance_policy.premium 
              amount_to_disburse = loan.amount - premia
            else
              premia = "NA"
            end
            processing_fee = 0
            others = 0
            if loan.applicable_fees
              loan.applicable_fees.each do |fee|
                if Fee.get(fee.fee_id).name =~ /rocessing/
                  processing_fee += fee.amount
                else
                  others += fee.amount
                end
              end
            end
            table.data.push({"Loan\nID" => loan.id, "Customer\nID" => loan.client.id, "Customer\nname" => loan.client.name, 
                              "Loan\nProduct" => loan.loan_product.name, "Amount\nApplied" => loan.amount_applied_for, 
                              "Amount\nDisbursed" => loan.amount.to_currency,
                              "Insurance\nPremimum" => premia, "Loan Fee\n(Processing)" => processing_fee, 
                              "Others" => others, 
                              "Total\nReceivable" =>(amount_to_disburse||loan.amount.to_currency),  
                              "Customer\nSign" => "", "FO\nsign" => '', "ABM\nsign" => '' 
                            })
          end
          table.data.push({"Amount Sanctioned \nand Disbursed" => tot_amount.to_currency})
          table.column_order  = ["Loan\nID", "Customer\nID", "Customer\nname", "Loan\nProduct", "Amount\nApplied", 
                                 "Amount\nDisbursed", "Insurance\nPremium", "Loan Fee\n(Processing)", 
                                 "Others", "Total\nReceivable", "Customer\nSign", 
                                 "FO\nSign", "ABM\nSign"]
          table.show_lines    = :all
          table.shade_rows    = :none
          table.show_headings = true          
          table.shade_headings = true
          table.orientation   = :center
          table.position      = :center
          table.title_font_size = 16
          table.header_gap = 20
          pdf.text("\n")
          pdf.text "Disbursements today"
          pdf.text("\n")
          table.render_on(pdf)
        end        
      } #centers end
      pdf.save_as(filename)
      return pdf
    end
  end
end
