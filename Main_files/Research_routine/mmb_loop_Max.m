%Description: ....
%....
%Alexander Meyer-Gohde, Johanna Saecker


 

run_time_reps=1;
newton_options.dynare_reduced_sylvester=1;
newton_options.maximum_iterations=1000;
addpath('C:\dynare\5.1\matlab')
% MTCHANGE: commented out the first line below this line: addpath('..\algorithm\')
% % addpath('..\algorithm\')
%YourPath=''
%YourPath='C:\Users\saecker.ITS\PowerFolders\Newton_Saecker (Alexander Meyer-Gohde)\code\workspace\2021_10_15_js';
YourPath=pwd;
cd (YourPath)
addpath(pwd)

% MTCHANGE: replaced the code below to produce cell array of character
% vectors mmb_vec by the two lines below of that, table 'overview_out.xlsx'
% replaces the 'mmb_names.txt' file

% % %fileID = fopen('mmb_test.txt','r');
% % fileID = fopen('mmb_names.txt','r');
% % mmbline = fgetl(fileID);        
% % %geht hier vielleicht auch besser (ff. 5 Zeilen von mathworks-website)
% % mmb_vec = cell(0,1);            
% % while ischar(mmbline)           
% %     mmb_vec{end+1,1} = mmbline; 
% %     mmbline = fgetl(fileID);    
% % end    

ot = readtable('overview_out.xlsx');
mmb_vec= ot.model_name(logical(ot.model_folder_exists));


loop_n=size(mmb_vec,1);
% MTCHANGE: preallocate with nan instead of zeros
AMG_Results=nan(17,7,loop_n);

% MTCHANGE: add variable start and end to looping (also change in for loop
% start)
loop_start = 1;
loop_end = loop_n;
%loop_start = 26;
%loop_end = 30;
model_indexes = loop_start:loop_end;
% model_indexes = [4, 17];
iter_count = 0;
for loop_k=model_indexes
    %k=1;    %for testing
    % MTCHANGE: add detailed progress report
    iter_count = iter_count+1;
    fprintf(['\n\n\n--- New Iteration --- \n',...
             'Iteration: %1$3.i of %2$3.i, Model: %3$s, Completion: %4$3.1f %%\n\n'], ...
             iter_count,numel(model_indexes),mmb_vec{loop_k},100*(iter_count-1)/(numel(model_indexes)))
%MTCHANGE: adjust path
%change directory to folder path in MMB
cd([YourPath '\replication\' mmb_vec{loop_k}])

%MTCHANGE: add try catch block around model research process to catch error
%messages and report them

try
    %run dynare
    %dynare ([mmb_vec{k} '_rep']) 
    eval(['dynare ', mmb_vec{loop_k}, '_rep noclearall nograph nostrict  nolog'])
    %%%%% current problem: dynare_to_matrix_quadratic needs to be located in
    %%%%% mmb-rep-folders (e.g. BRA_SAMBA08_rep)
    AMG_Results(1,:,loop_k)=[M_.nstatic, M_.nfwrd, M_.npred, M_.nboth, M_.nsfwrd, M_.nspred, M_.ndynamic];
    
    
    [matrix_quadratic, jacobia_]=create_reduced_matrix_quadratic_from_dynare(M_,oo_);
    
    %tic; [info, oo_, options_]  = stoch_simul(M_, options_, oo_, var_list_); toc    
     tic; for jj=1:run_time_reps; [dr,info] = dyn_first_order_solver(jacobia_,M_,oo_.dr,options_,0); end;   AMG_Results(2,1,loop_k) = toc/run_time_reps;   
    
     
     
    ALPHA_ZS_dynare=[zeros(M_.endo_nbr,M_.nstatic) oo_.dr.ghx zeros(M_.endo_nbr,M_.nfwrd)];
    X_dynare=ALPHA_ZS_dynare;
    matrix_quadratic.X=ALPHA_ZS_dynare;
    try
    if M_.endo_nbr>100; [errors]=dsge_backward_errors_condition_sparse_minimal(matrix_quadratic); else [errors]=dsge_backward_errors_condition_full(matrix_quadratic);end
    AMG_Results(3:end,1:5,loop_k)=errors;
    ot.error_flag(strcmp(ot.model_name,mmb_vec{loop_k})) = 0;
    ot.error(strcmp(ot.model_name,mmb_vec{loop_k})) = string("N/A");
    catch
    AMG_Results(3:end,1:5,loop_k)=NaN(15,5);
    end
    
catch ME
    ot.error(strcmp(ot.model_name,mmb_vec{loop_k})) = string(process_exception(ME));
    ot.error_flag(strcmp(ot.model_name,mmb_vec{loop_k})) = 1;
    warning('ERROR caught in model %s\n\n', mmb_vec{loop_k})
end

cd([YourPath])

% MTCHANGE: output to command window
fprintf('End of iteration %1$3.i of %2$3.i, Model: %3$s, Completion: %4$3.1f %%\n', ...
        iter_count,numel(model_indexes),mmb_vec{loop_k},100*(iter_count)/(numel(model_indexes)))
%save certain results somewhere
% MTCHANGE: include loop_start, loop_end, iter_count and model_indexes, include ot
clearvars -except loop_k loop_n loop_start loop_end iter_count model_indexes ot AMG_JS_Results YourPath mmb_vec run_time_reps newton_options

end
% MTCHANGE: Export info on errors in overview table
ot = movevars(ot,"error","After","copyexitstatus");
ot = movevars(ot,"error_flag","After","error");
writetable(ot,'Result_allmodels.xlsx','Sheet','Info');
% MTCHANGE: save results outside of the foor loop
clearvars -except AMG_JS_Results YourPath mmb_vec run_time_reps newton_options
save First_Run_AMG_JS
