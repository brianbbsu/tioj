class ContestsController < ApplicationController
  before_filter :authenticate_admin!, except: [:dashboard, :index, :show]
  before_filter :set_contest, only: [:show, :edit, :update, :destroy, :dashboard, :set_contest_task]
  before_filter :set_tasks, only: [:show, :dashboard, :set_contest_task]
  layout :set_contest_layout, only: [:show, :dashboard]

  def set_contest_task
    redirect_to contest_path(@contest)
    case params[:alter_to].to_i
      when 0
        flash[:notice] = "Contest tasks set to public."
      when 1
        flash[:notice] = "Contest tasks set to only visible during contest."
      when 2
        flash[:notice] = "Contest tasks set to invisible."
      else
        return
    end
    @tasks.map{|a| a.update(:visible_state => params[:alter_to].to_i)}
  end
  
  def dashboard
    if Time.now < @contest.start_time
      authenticate_admin!
    end

    c_submissions = nil
    if @contest.contest_type == 1 and Time.now >= @contest.start_time and Time.now <= @contest.end_time
      authenticate_user!
      if not current_user.admin?
        c_submissions = @contest.submissions.where("user_id = ?", current_user.id)
        flash[:notice] = "You can only see your own score."
      else
        c_submissions = @contest.submissions
      end
    else
      c_submissions = @contest.submissions
    end
    
    @submissions = []
    @participants = []
    @tasks.each_with_index do |task, index|
      @submissions << c_submissions.where("problem_id = ?", task.id)
      @participants = @participants | @submissions[index].map{|e| e.user_id}
    end
    @scores = []
    if @contest.contest_type == 2
      #penalty
      @participants.each do |u|
        t = []
        total_attm = 0
        total_solv = 0
        penalty = 0
        (0..(@tasks.size-1)).each do |index|
          succ = @submissions[index].select{|a| a.user_id == u and a.result == 'AC'}.min_by{|a| a.id}
          if succ
            attm = @submissions[index].select{|a| a.user_id == u and a.id < succ.id}.size
            t << [attm+1, (succ.created_at - @contest.start_time).to_i / 60]
            total_solv += 1
            total_attm += attm+1
            penalty += attm * 20
          else
            attm = @submissions[index].select{|a| a.user_id == u}.size
            t << [attm, 0]
            total_attm += attm
          end
        end
        @scores << [u, total_attm, total_solv, t, t.map{|a| a[1]}.sum + penalty]
      end
      @scores = @scores.sort{|a, b| a[2] != b[2] ? -(a[2] <=> b[2]) : a[4] <=> b[4]}
      @color = @scores.map{|a| a[2]}.uniq.sort_by{|a| -a}
      @color << 0
    else
      @participants.each do |u|
        t = []
        (0..(@tasks.size-1)).each do |index|
          if @submissions[index].select{|a| a.user_id == u}.empty?
            t << 0
          else
            t << @submissions[index].select{|a| a.user_id == u}.max_by{|a| a.score}.score
          end
        end
        @scores << [u, t, t.sum]
      end
      @scores = @scores.sort_by{|a| -a[2]}
      @color = @scores.map{|a| a[2]}.uniq.sort_by{|a| -a}
      @color << 0
    end

    set_page_title ("Dashboard - " + @contest.title)
  end

  def index
    @contests = Contest.order("id DESC").page(params[:page])
    set_page_title "Contests"
  end

  def show
    if Time.now < @contest.start_time
      unless user_signed_in? and current_user.admin?
        flash[:notice] = 'Contest has not yet started.'
        redirect_to action:'index'
        return
      end
    end
    set_page_title @contest.title
  end

  def new
    @contest = Contest.new
    3.times { @contest.contest_problem_joints.build }
    set_page_title "New contest"
  end

  def edit
    set_page_title ("Edit contest - " + @contest.title)
  end

  def create
    @contest = Contest.new(contest_params)
    respond_to do |format|
      if @contest.save
        format.html { redirect_to @contest, notice: 'Contest was successfully created.' }
        format.json { render action: 'show', status: :created, location: @contest }
      else
        format.html { render action: 'new' }
        format.json { render json: @contest.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    respond_to do |format|
      if @contest.update(contest_params)
        format.html { redirect_to @contest, notice: 'Contest was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: 'edit' }
        format.json { render json: @contest.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @contest.destroy
    respond_to do |format|
      format.html { redirect_to contests_url }
      format.json { head :no_content }
    end
  end

  private
  def set_contest
    @contest = Contest.find(params[:id])
  end
  
  def set_tasks
    @tasks = @contest.contest_problem_joints.order("id ASC").map{|e| e.problem}
  end

  # Never trust parameters from the scary internet, only allow the white list through.
  def contest_params
    params.require(:contest).permit(
      :id,
      :title,
      :description,
      :start_time,
      :end_time,
      :contest_type,
      contest_problem_joints_attributes: 
      [
        :id,
        :problem_id,
        :_destroy
      ]
    )
  end
end
