function []=model_fit_to_power_waveform_dynamic(filesBulk, name_bs, cnf_p, cst_p, chd_p,  filename_L1_ISR, SWH, SSH, sigma0, epoch, Pu, COR, cnf_tool, varargin)

% -------------------------------------------------------------------------
% Created by isardSAT S.L. 
% -------------------------------------------------------------------------
% This code plots the fitted curves from retrieved parameters in L2 HR files generated by isardSAT using retracker based on the original model developed 
% by Chirs Ray et al. in IEEE TGRS "SAR Altimeter Backscattered Waveform Model" 
% DOI:10.1109/TGRS.2014.23330423
% -------------------------------------------------------------------------
% 
% Author:           Alba Granados / isardSAT
%
% Reviewer:        ------ / isardSAT
%
% Last revision:    Alba Granados / isardSAT V1 30/08/2020
% This software is built within the Sentinel-6 P4 L1 GPP project - CCN 3 - WP 1700
% -------------------------------------------------------------------------
% -------------------------------------------------------------------------
% INPUT:
%      MANDATORY
%       -filesBulk{}    =   cell array of length num. of baselines of structures of input files within the folder where
%       to process the data (including the L1B as well as configuration/characterization files):
%        filesBulk{}.inputPath        --> full path to the input L1B folder
%        filesBulk{}.resultPath       --> full path to results folder save L2 prod
%        filesBulk{}.inputPath_L1BS   --> full path to input L1BS folder
%        filesBulk{}.cnf_chd_cst_path --> full path to cnf/chd/cst/LUTs folder
%        filesBulk{}.CNF_file         --> full filename cnf config file
%        filesBulk{}.CHD_file         --> full filename chd charac file
%        filesBulk{}.CST_file         --> full filename cst const file
%        filesBulk{}.LUT_f0_file      --> full filename LUT for f0 function
%        filesBulk{}.LUT_f1_file      --> full filename LUT for f1 function
%        filesBulk{}.nFilesL1B        --> total number of L1B to be processed
%        filesBulk{}.L1BFiles         --> information of the L1B files to be
%                                       processed: fields--> {name,date,bytes,isdir,datenum}
%       - name_bs = cell array containing baselines names
%       - cnf_p, cst_p, chd_p = configuration, constant and characterization parameters structure for L2 processing
%       - filename_L1_ISR = cell array containg L1 file name for each baseline
%       - SWH, sigma0, epoch, Pu, COR = N_baselines x num. records array with retrieved parameters from L2 product
%       - cnf_tool, structure containing plot options in jason config file
% 
%      OPTIONAL

%       
% OUTPUT:
%       -generated plots
%
% -------------------------------------------------------------------------
% -------------------------------------------------------------------------
% CALLED FUNCTIONS/ROUTINES
%  - read_alt_data_EM: read input data from any combination of mission and
%      processor either in netcdf mat or DBL and save it in a common data
%      structure to be used in the L2 processing
% - gen_nonfit_params_EM: generates and initializes the structure of
%                         non-fitting data parameters
%
% -------------------------------------------------------------------------
% -------------------------------------------------------------------------
% COMMENTS/RESTRICTIONS
% - Need to optimize the code avoiding so many different data structures
% - LR waveform fitting is missing
% 
% -------------------------------------------------------------------------  
% -------------------------------------------------------------------------
% Versions control:

%% --------------- HANDLING OPTIONAL INPUTS ---------------------------
if(nargin<6)
    error('Wrong number of input parameters');
end
p = inputParser;
p.addParamValue('filename_mask_KML','',@(x)ischar(x));

p.parse(varargin{:});
filename_mask_KML=p.Results.filename_mask_KML;
clear p;

switch lower(cnf_tool.figure_format)
    case 'eps'
        file_ext='.eps';    
        print_file='-depsc';
    case 'png'
        file_ext='.png';
        print_file='-dpng';
    case 'jpg'
        file_ext='.jpg';
        print_file='-djpeg';    
end

color_bs = cnf_tool.color_bs;
linestyle_wfm_bs = cnf_tool.LineStyle_wfm;

%% ---------- number of baselines to be compared -------------------------
N_baselines = length(filesBulk);


%% --------------- Configuration/characterization/LUTS --------------------

LUT_f0_file = filesBulk(1).LUT_f0_file;
LUT_f1_file = filesBulk(1).LUT_f1_file;


%% ----------- READING FILE FOR EACH BASELINE -----------------------------

indx_LR = 0;
bsl_HR = 1;

for i_baseline=1:N_baselines
        
%     fprintf('Num surfaces L2 (%s): %d\n', char(name_bs(i_baseline)), length(SWH{i_baseline}));    

    if ~isempty(find(ismember(strsplit(filename_L1_ISR{i_baseline}, '_'), 'LR'))) || (~cnf_tool.plot_fitted_waveforms_bs(i_baseline)) % skip LR - check output L2 processor LR for fitted waveforms
        indx_LR = i_baseline;
        continue;
    end

    % required function for analytical curve reconstruction
    [data{i_baseline},flag] = read_alt_data_EM (filename_L1_ISR{i_baseline}, cnf_p,cst_p,chd_p,'filename_mask_KML',filename_mask_KML);

    if bsl_HR == 1 && ~isempty(find(ismember(strsplit(filename_L1_ISR{i_baseline}, '_'), 'HR')))
        bsl_HR = i_baseline;
        
        cnf_p.rou_flag=0;
        [nf_p] = gen_nonfit_params_EM (data{i_baseline},cnf_p,chd_p,cst_p); 

        % ------------- LOADING THE LUTS -----------------------------------------
        if (cnf_p.lut_flag)
            [~,~,LUT_f0_file_ext]=fileparts(LUT_f0_file);
            switch LUT_f0_file_ext
                case '.mat'
                    load(LUT_f0_file,'func_f0');
                otherwise
                    error('No valid LUT f0 file format');
            end
            switch cnf_p.power_wfm_model
                case 'complete'
                    [~,~,LUT_f1_file_ext]=fileparts(LUT_f1_file);
                    switch LUT_f1_file_ext
                        case '.mat'
                            load(LUT_f1_file,'func_f1');
                        otherwise
                            error('No valid LUT f1 file format');
                    end
                otherwise
                    error('No valid power waveform model')
            end
        end

        % read non-fit parameters which are single value
        nf_params.waveskew  =   nf_p.waveskew;
        nf_params.EMbias    =   nf_p.EMbias;
        nf_params.rou       =   nf_p.rou;
        nf_params.Npulses   =   nf_p.Npulses;
        nf_params.alphag_a  =   nf_p.alphag_a;
        nf_params.alphag_r  =   nf_p.alphag_r;
        nf_params.Nbcycle   =   nf_p.Nbcycle;
        nf_params.bw_Rx     =   nf_p.bw_Rx;
        nf_params.Nsamples  =   nf_p.Nsamples;

        nf_params.A_s2Ga= nf_p.A_s2Ga;
        nf_params.A_s2Gr= nf_p.A_s2Gr;
    end  


    switch cnf_p.mode
        case {'SAR','SARin','RAW','LR-RMC','FF-RAW','FF-RMC'}
            data{i_baseline}.HRM.power_wav_filtered    =   data{i_baseline}.HRM.power_wav(cnf_p.IFmask_N*cnf_p.ZP+1:end-(cnf_p.IFmask_N*cnf_p.ZP),:)';
        case {'RMC'} %RMC
            data{i_baseline}.HRM.power_wav_filtered    =   data{i_baseline}.HRM.power_wav(cnf_p.IFmask_N*cnf_p.ZP+1:end,:)';
        otherwise
            error('not a valid mode');
    end
    switch cnf_p.range_index_method
        case 'conventional'
            range_index_comm{i_baseline}=1:1:data{i_baseline}.N_samples;
        case 'resampling'            
            range_index_comm{i_baseline}=[1:1/cnf_p.ZP:(data{i_baseline}.N_samples/cnf_p.ZP),...
                                (data{i_baseline}.N_samples/cnf_p.ZP+1/cnf_p.ZP):1/cnf_p.ZP:(data{i_baseline}.N_samples/cnf_p.ZP+1/cnf_p.ZP*(cnf_p.ZP-1))];
    end
    % derive fitting parameters from estimates saved in files 
    switch cnf_p.range_index_method
        case 'conventional'
            delta_rb=cst_p.c_cst./(2.0*data{i_baseline}.HRM.fs_clock_ku_surf*cnf_p.ZP);
        case 'resampling'
            delta_rb=cst_p.c_cst./(2.0*data{i_baseline}.HRM.fs_clock_ku_surf);
    end  
    epoch{i_baseline} = (cst_p.c_cst./(2*delta_rb)).*epoch{i_baseline}+cnf_p.ref_sample_wd;

end


% % compute filtered geophysical parameters estimates to plot them below
% fitted curve
[lat_surf, lon_surf, SSH_filtered, SWH_filtered, sigma0_filtered, COR_filtered, SSH_RMSE, SWH_RMSE, sigma0_RMSE, COR_RMSE, SSH_std_mean, SWH_std_mean, sigma0_std_mean, COR_std_mean, ...
    SSH_mean, SWH_mean, sigma0_mean, COR_mean] = performance_baselines_S6_dynamic(SSH, SWH, sigma0, COR, filename_L1_ISR, ...
    [],name_bs, cnf_tool);


%% ---------------- PLOTTING RESULTS -----------------------------------

% assume same number of surfaces
if indx_LR > 0
    L2_num_surfaces = length(SWH{length(name_bs)-indx_LR + 1});    
    L2_num_surfaces_LR = length(SWH{indx_LR});
else
    L2_num_surfaces = length(SWH{1});
    L2_num_surfaces_LR = 0;
end

fprintf('Total # wvfms %d\n',L2_num_surfaces);

for m = 1:L2_num_surfaces

	if ((mod(m,cnf_tool.plot_downsampling)==0) || (m==1)) 

        text_interpreter=get(0, 'defaultAxesTickLabelInterpreter'); %cnf_p.text_interpreter;      
        
	    f1=figure;
	    textbox_string = {''};
        [~,file_id,~]=fileparts(filename_L1_ISR{i_baseline});
        plot_baseline = 0;
	    for i_baseline=1:N_baselines

            if i_baseline == indx_LR || ~cnf_tool.plot_fitted_waveforms_bs(i_baseline)
                continue;
            end           
            
            plot_baseline = plot_baseline + 1;
            fprintf('Plot surface #%s of baseline %d\n',num2str(m), i_baseline);
            
            if plot_baseline==1
                ftrack=figure;
                axesm eckert4;
                framem; gridm;
                axis off
                worldmap('argentina')
                geoshow('landareas.shp', 'FaceColor', 'none', 'EdgeColor', 'black');
                scatterm(lat_surf{i_baseline}(1:m), lon_surf{i_baseline}(1:m), 200, SWH_filtered{i_baseline}(1:m), 'filled');
%                 scatterm(data{i_baseline}.GEO.LAT, data{i_baseline}.GEO.LON, 'marker','.','markerfacecolor','k'); %,'markersize',5);
%                 scatterm(data{i_baseline}.GEO.LAT(m), data{i_baseline}.GEO.LON(m), 'marker','.','markerfacecolor','r'); %,'markersize',5);
    %             hcb = colorbar('southoutside');
    %             set(get(hcb,'Xlabel'),'String','SSH [m]')
                print(print_file,cnf_tool.res_fig,[filesBulk(i_baseline).resultPath,file_id,'_maptrack',file_ext]);
                close(ftrack);
            end   
            subplot(2,6,[1,2,3,4,5,6]);
            I = imread([filesBulk(i_baseline).resultPath,file_id,'_maptrack',file_ext]);
            hold on;
            ha2=axes('position',[.437, 0.672, .25, .25,]);   % plots
            image(I)
            set(ha2,'handlevisibility','off','visible','off')        
            
            if ~cnf_tool.overlay_baselines
                if i_baseline==1 
                    close(f1); 
                end
                f1=figure;
                coef_width = 1;
            else            
                % plot measured waveform
                coef_width=1.1*0.6^(plot_baseline-1);
            end

%             subplot(2,2,1);
            plt_meas(i_baseline) = plot(1:data{i_baseline}.N_samples,data{i_baseline}.HRM.power_wav_filtered(m,:)/max(data{i_baseline}.HRM.power_wav_filtered(m,:)),...
                'Color', color_bs(i_baseline,:), 'LineWidth', coef_width*cnf_tool.default_linewidth_wfm); % 'LineStyle', linestyle_wfm_bs{i_baseline}, 
            plt_meas(i_baseline).Color(4) = 0.6; % 0.99; % Alba: for ESA presentation
            hold on   

                        
            % build analytical waveform based on /retracker/fitting_noise_method.m
            start_sample=1;
            stop_sample=data{i_baseline}.N_samples; 
            if cnf_p.wvfm_discard_samples
                start_sample=max(start_sample,1+cnf_p.wvfm_discard_samples_begin);
                stop_sample=min(stop_sample,data{i_baseline}.N_samples-cnf_p.wvfm_discard_samples_end);    
            end
            range_index=range_index_comm{i_baseline}(start_sample:stop_sample);

            nf_params.h         =   nf_p.h(m);
            nf_params.xp        =   nf_p.xp(m);
            nf_params.yp        =   nf_p.yp(m);
            nf_params.alphax    =   nf_p.alphax(m);
            nf_params.alphay 	=   nf_p.alphay(m);
            nf_params.Lx        =   nf_p.Lx(m);
            nf_params.Ly        =   nf_p.Ly(m);
            nf_params.Lz        =   nf_p.Lz(m);
            nf_params.Lgamma    =   nf_p.Lgamma(m);
            nf_params.Neff      =   nf_p.Neff(m); 
            nf_params.fs_clock  =   data{i_baseline}.HRM.fs_clock_ku_surf(m);

            % data to fit
            max_power_wav       =   max(data{i_baseline}.HRM.power_wav_filtered(m,start_sample:stop_sample));
            fit_data            =   data{i_baseline}.HRM.power_wav_filtered(m,start_sample:stop_sample)/max_power_wav;
            nf_params.max_power_wav=max_power_wav;

            % look indexation
               switch cnf_p.looks_index_method
                case 'Cris_old'
                    N_Tlooks    =   nf_p.Neff(m);
                    looks       =   (-floor((N_Tlooks-1)/2):floor(N_Tlooks/2)).';                
               case 'Norm_index'
                    N_Tlooks    =   nf_p.Neff(m);
                    looks       =   -floor((N_Tlooks-1)/2):floor(N_Tlooks/2);
                    looks       =   (looks)/(nf_p.Npulses); 
               case 'Doppler_freq'
                    switch cnf_p.fd_method
                        case 'exact'
                            looks=2.0/chd_p.wv_length_ku.*data{i_baseline}.GEO.V_stack(m,1:nf_p.Neff(m)).*cos(data{i_baseline}.HRM.beam_ang_stack(m,1:nf_p.Neff(m))).*...
                                data{i_baseline}.HRM.pri_stack(m,1:nf_p.Neff(m)).*nf_p.Npulses;
                        case 'approximate'                   
                            switch cnf_p.mission
                                case {'S6'}
                                    beam_angles=...
                                        linspace(pi/2-data{i_baseline}.HRM.doppler_angle_start_surf(m),...
                                        pi/2-data{i_baseline}.HRM.doppler_angle_stop_surf(m),nf_p.Neff(m)).';                                                            
                                otherwise
                                    beam_angles=...
                                        linspace(pi/2+data{i_baseline}.HRM.doppler_angle_start_surf(m)-data{i_baseline}.HRM.look_ang_start_surf(m),...
                                        pi/2+data{i_baseline}.HRM.doppler_angle_stop_surf(m)-data{i_baseline}.HRM.look_ang_stop_surf(m),nf_p.Neff(m)).';                                
                            end     
                            looks=2.0/chd_p.wv_length_ku.*data{i_baseline}.GEO.V(m).*cos(beam_angles).*data{i_baseline}.HRM.pri_surf(m).*nf_p.Npulses;                                
                            fd=2.0/chd_p.wv_length_ku.*data{i_baseline}.GEO.V(m).*cos(beam_angles);
                    end 
               case 'Look_angle'
                   if data{i_baseline}.HRM.pri_surf(m)==0
                       data{i_baseline}.HRM.pri_surf(m)=data{i_baseline}.HRM.pri_surf(idx_pri_non_zero);
                   end
                   delta_look_angle=asin(chd_p.wv_length_ku./(data{i_baseline}.HRM.pri_surf(m).*2.0*...
                                        nf_p.Npulses*data{i_baseline}.GEO.V(m))); 
                   nf_params.delta_look_angle=delta_look_angle;
                   switch cnf_p.look_ang_method
                        case 'exact'
                            looks=data{i_baseline}.HRM.look_ang_stack(m,1:nf_p.Neff(m)).'/delta_look_angle;
                            look_angles = looks*delta_look_angle;
                        case 'approximate'
                            looks=(linspace(data{i_baseline}.HRM.look_ang_start_surf(m),...
                                data{i_baseline}.HRM.look_ang_stop_surf(m),nf_p.Neff(m))/delta_look_angle).';
                            look_angles=(looks.*delta_look_angle).';

                    end 
               end 

            % Create the mask (as a matrix) 
            nf_params.Doppler_mask=ones(nf_params.Neff,data{i_baseline}.N_samples);
            switch lower(cnf_p.Doppler_mask_cons_option)
                case 'external'
                   if isfield(data{i_baseline}.HRM,'Doppler_mask')           
                       if cnf_p.use_zeros_cnf == 1
                           value_mask=1*0;
                       else
                           value_mask=NaN;
                       end
                       for i_look=1:nf_params.Neff
                           if data{i_baseline}.HRM.Doppler_mask(i_look,m)>0
                               nf_params.Doppler_mask(i_look,data{i_baseline}.HRM.Doppler_mask(i_look,m):end)=value_mask;
                           else
                               nf_params.Doppler_mask(i_look,:)=NaN;
                           end
                       end
                   end
                   nf_params.Doppler_mask=nf_params.Doppler_mask(:,start_sample:stop_sample);
                case 'internal'
                    nf_params.range_history=compute_range_history_approx(data,nf_p,cnf_p,chd_p,m); 
                    if isfield(data{i_baseline}.HRM,'Doppler_mask')
                        nf_params.Doppler_mask_beams_all_zeros_original= data{i_baseline}.HRM.Doppler_mask(1:nf_params.Neff,m)==1; 
                    else
                        nf_params.Doppler_mask_beams_all_zeros_original=logical(zeros(1,nf_params.Neff));
                    end
                    switch lower(cnf_p.Doppler_mask_cons_internal)
                        case 'l1b_like'
                            if cnf_p.use_zeros_cnf == 1
                                value_mask=1*0;
                            else
                                value_mask=NaN;
                            end
                            for i_look=1:nf_params.Neff
                                if nf_params.range_history(i_look)<data{i_baseline}.N_samples
                                    nf_params.Doppler_mask(i_look,(data{i_baseline}.N_samples-nf_params.range_history(i_look)):end)=value_mask;
                                else
                                    nf_params.Doppler_mask(i_look,1:end)=value_mask;
                                end
                            end
                            nf_params.Doppler_mask(nf_params.Doppler_mask_beams_all_zeros_original,:)=value_mask;
                            nf_params.Doppler_mask=nf_params.Doppler_mask(:,start_sample:stop_sample);
                    end   
            end        

            % ThN
            if cnf_p.Thn_flag
                switch lower(cnf_p.Thn_estimation_method)
                    case 'external'
                        nf_params.ThN        =ones(1,nf_p.Neff(m)).*cnf_p.external_Thn_value; %normalized as the waveform is normalized
                    case 'fixed_window'
                        switch cnf_p.Thn_ML_SL_method
                            case 'ML'
                                nf_params.ThN        =   mean(fit_data(cnf_p.Thn_w_first:cnf_p.Thn_w_first+cnf_p.Thn_w_width-1))*ones(1,nf_p.Neff(m));
                            case 'SL'
                                dumm=squeeze(data.HRM.beams_rng_cmpr_mask(m,1:nf_p.Neff(m),:));
                                dumm(~isfinite(dumm))=NaN;
                                dumm(dumm==0)=NaN;
                                max_mean_dumm=max(mean(dumm,1,'omitnan'));
                                for i_beam=1:nf_p.Neff(m)
                                    nf_params.ThN(i_beam)        =   mean(dumm(i_beam,cnf_p.Thn_w_first:cnf_p.Thn_w_first+cnf_p.Thn_w_width-1)/max_mean_dumm,'omitnan');
                                end
                                clear dumm;
                        end
                    case 'adaptive'
                        switch cnf_p.Thn_ML_SL_method
                            case 'ML'
                                idx_noise=[];
                                temp_noise_thr=cnf_p.threshold_noise;
                                iter_noise=1;
                                while isempty(idx_noise) && iter_noise<cnf_p.max_iter_noise
                                    idx_noise=find(abs(diff(fit_data))<=temp_noise_thr);
                                    idx_noise=idx_noise(idx_noise<idx_leading_edge);
                                    temp_noise_thr=temp_noise_thr*cnf_p.factor_increase_noise_iter;
                                    iter_noise=iter_noise+1;
                                end
                                if iter_noise<cnf_p.max_iter_noise
                                    nf_params.ThN        =   mean(fit_data(idx_noise))*ones(1,length(looks));
                                    clear idx_noise tempo_noise_thr;
                                else
                                    if m~=1
                                        nf_params.ThN         = mean(nf_params.ThN)*ones(1,length(looks));
                                    else
                                        nf_params.ThN         = min(fit_data)*ones(1,length(looks));
                                    end
                                end
                            case 'SL'
                                nf_params.ThN = zeros(1,nf_p.Neff(m));                    
                        end
                end
            else
                nf_params.ThN = zeros(1,nf_p.Neff(m));
            end

            % fitted parameters
            fit_params(1) = epoch{i_baseline}(m) - cnf_p.IFmask_N*cnf_p.ZP + 1; 
            fit_params(2) =  SWH{i_baseline}(m)/4; 
            fit_params(3) = 1/max_power_wav*Pu{i_baseline}(m);

            if cnf_p.lut_flag
                switch cnf_p.power_wfm_model
                    case 'simple'
                        [ml_wav,~,~]          =   ml_wave_gen(range_index,fit_params,nf_params, cnf_p, chd_p,looks,func_f0);

                    case 'complete'
                        [ml_wav,~,~]          =   ml_wave_gen(range_index,fit_params,nf_params, cnf_p, chd_p,looks,func_f0,func_f1);
                end
            else
                [ml_wav,~,~]          =   ml_wave_gen(range_index,fit_params,nf_params, cnf_p, chd_p,looks);
            end

            % % plot analytical fit
            coef_width = 0.4;
            if cnf_tool.overlay_baselines    
                coef_width=0.5*0.9^(plot_baseline-1);
            end
%             if i_baseline==3
%                 plt_anal(i_baseline)=plot(start_sample:stop_sample,ml_wav, 'Color', [150/255,	150/255,	150/255], 'LineStyle', '--', ...
%                     'LineWidth', 0.2*cnf_tool.default_linewidth_wfm);
%             else
                plt_anal(i_baseline)=plot(start_sample:stop_sample,ml_wav, 'Color', color_bs(i_baseline,:), 'LineStyle', linestyle_wfm_bs{i_baseline}, ...
                    'LineWidth', coef_width*cnf_tool.default_linewidth_wfm);
%             end
            
            Pu_m = 10*log10(fit_params(3)*max_power_wav);
            epoch_m = fit_params(1) + cnf_p.IFmask_N*cnf_p.ZP - 1; 
            Hs_m   =   fit_params(2)*4;

            if ~cnf_tool.overlay_baselines
                textbox_string = {''};
            end
            if strcmp(text_interpreter, 'latex')
                textbox_string = [textbox_string, strcat(char(name_bs(i_baseline)), ':'), ['Epoch = ', num2str(epoch_m,4), ' [r.b]'], sprintf('SWH = %g [m]' ,abs(Hs_m)),sprintf('Pu = %g [dB]', Pu_m), ...
                        ['$\rho$ = ', num2str(COR{i_baseline}(m),5), ' [\%]'], strcat('$\sigma^0$ = ', sprintf('%.4g [dB]', sigma0{i_baseline}(m)))];        
            else
                textbox_string = [textbox_string, strcat(char(name_bs(i_baseline)), ':'), ['Epoch = ', num2str(epoch_m,4), ' [r.b]'], sprintf('SWH = %g [m]' ,abs(Hs_m)),sprintf('Pu = %g [dB]', Pu_m), ...
                    ['\rho = ', num2str(COR{i_baseline}(m),5), ' [%]'], strcat('\sigma^0 = ', sprintf('%.4g [dB]', sigma0{i_baseline}(m)))];        
            end
            
            if i_baseline~=N_baselines
                textbox_string = [textbox_string, sprintf('\n')];
            end

            if ~cnf_tool.overlay_baselines
                legend_text={'L1b-Waveform', 'Analytical fit'};
                h_leg=legend(legend_text(~cellfun(@isempty,legend_text)),'Location','northeastoutside','Fontsize',cnf_tool.legend_fontsize);
                pos_leg=get(h_leg,'Position');

                y1=get(gca,'ylim'); 
                plt_limits=plot([stop_sample stop_sample],y1, '--k', 'LineWidth',0.6);
                plt_anal(i_baseline)=plot([start_sample start_sample],y1, '--k', 'LineWidth',0.6);
                grid on
                xlabel('range bin',  'interpreter',text_interpreter);
                
                if strcmp(text_interpreter, 'latex')
                    title_text = [sprintf('wav. \\# %d (LAT: %.4g deg)', m, data{i_baseline}.GEO.LAT(m))];
                else
                    title_text = [sprintf('wav. # %d (LAT: %.4g deg)', m, data{i_baseline}.GEO.LAT(m))];
                end                
%                 if isfield(data{i_baseline}.GLOBAL_ATT.DATA_FILE_INFO, 'cycle_number')
%                     title_text = [title_text, sprintf(' - cycle %d pass %d', data{i_baseline}.GLOBAL_ATT.DATA_FILE_INFO.cycle_number, data{i_baseline}.GLOBAL_ATT.DATA_FILE_INFO.pass_number)]; 
%                 end
                title(title_text, 'Interpreter',text_interpreter); 

                axis([1 data{i_baseline}.N_samples 0 1.0]);
                textbox_string=textbox_string(~cellfun(@isempty,textbox_string));
                h=annotation('textbox', [pos_leg(1),pos_leg(2)-1.3*pos_leg(4),pos_leg(3),pos_leg(4)],...
                    'String',textbox_string,...
                    'FitBoxToText','on',  'interpreter',text_interpreter,  'Fontsize', cnf_tool.textbox_fontsize);
                h.LineWidth = 0.5;
                addlogoisardSAT('plot');
                
                print(print_file,cnf_tool.res_fig,[filesBulk(i_baseline).resultPath,file_id,'_',char(name_bs(i_baseline)) ,'_W',num2str(m,'%04.0f'),file_ext]);
                
                if cnf_tool.save_figure_format_fig
                   savefig([filesBulk(i_baseline).resultPath,file_id,'_',char(name_bs(i_baseline)) ,'_W',num2str(m,'%04.0f'),'.fig']) 
                end
                close(f1);
            else
                hold on;
            end
	    end
	    
	    if cnf_tool.overlay_baselines && sum(cnf_tool.plot_fitted_waveforms_bs)>0
            legend_text_meas = {''}; legend_text_anal = {''};
            for i_baseline=1:N_baselines
                if i_baseline == indx_LR
                    continue;
                end
                uistack(plt_anal(i_baseline),'top');
                legend_text_meas=[legend_text_meas, sprintf('%s L1b-Waveform', char(name_bs(i_baseline)))];
                legend_text_anal=[legend_text_anal, sprintf('%s Model', char(name_bs(i_baseline)))];
            end
            y1=get(gca,'ylim'); 
            plot([stop_sample stop_sample],y1, '--k', 'LineWidth',0.6);
            plot([start_sample start_sample],y1, '--k', 'LineWidth',0.6);
            legend_text=[legend_text_meas, legend_text_anal, 'Fitting range limit'];

            h_leg=legend(legend_text(~cellfun(@isempty,legend_text)),'Location','northeastoutside','Fontsize',cnf_tool.legend_fontsize);
            pos_leg=get(h_leg,'Position');
            textbox_string=textbox_string(~cellfun(@isempty,textbox_string));
            xlabel('range bin',  'interpreter',text_interpreter);
            if indx_LR > 0
                baseline_HR = length(name_bs)-indx_LR + 1;
            else
                baseline_HR = i_baseline;
            end
            
            if strcmp(text_interpreter, 'latex')
                title_text = [sprintf('HR waveform \\# %04d (LAT: %.02f deg)', m, data{baseline_HR}.GEO.LAT(m))];
            else
                title_text = [sprintf('HR waveform # %04d (LAT: %.02f deg)', m, data{baseline_HR}.GEO.LAT(m))];
            end                
%             if isfield(data{baseline_HR}.GLOBAL_ATT.DATA_FILE_INFO, 'cycle_number')
%                 title_text = [title_text, sprintf(' - cycle %d pass %d', data{baseline_HR}.GLOBAL_ATT.DATA_FILE_INFO.cycle_number, data{baseline_HR}.GLOBAL_ATT.DATA_FILE_INFO.pass_number)]; 
%             end
            title(title_text, 'Interpreter',text_interpreter); 
            axis([1 data{baseline_HR}.N_samples 0 1.0]);
  
            addlogoisardSAT('plot');
            
            % % plot geophysical parameter estimate
            % SWH
            subplot(2,6,[7,8]);
            text_in_textbox={''};
            plot_baseline = 1;
            for b=1:N_baselines
                coef_width=1*0.6^(plot_baseline-1);
                plot_baseline = plot_baseline + 1;
                plt=plot(lat_surf{b}(1:m),SWH_filtered{b}(1:m),'Marker',cnf_tool.marker_bs{b},'Color',color_bs(b,:),...
                    'LineStyle',cnf_tool.LineStyle{b}, 'MarkerSize', cnf_tool.default_markersize, 'LineWidth', coef_width*cnf_tool.default_linewidth);
                plt.Color(4) = 1; % transparency
                hold on;
                legend_text=[legend_text,name_bs(b)];
        %         text_in_textbox=[text_in_textbox, strcat(char(name_bs(b)), ':'), sprintf('RMSE = %.4g [m]\nstd = %.4g [m]\nBias = %.4g [m]', ...
        %             SSH_RMSE(b), SSH_std_mean(b), nanmean(SSH_mean{b}-bias_compensation)-ref_SSH)];
                text_in_textbox=[text_in_textbox, strcat(char(name_bs(b)), ':'), sprintf('RMSE = %.4g [m]\nstd = %.4g [m]\nmean = %.4g [m]', ...
                    SWH_RMSE(b), SWH_std_mean(b), nanmean(SWH_mean{b}))];
                if b ~= N_baselines
                   text_in_textbox = [text_in_textbox, sprintf('\n')]; 
                end
            end
            set(gca,'Xdir','reverse')
            plot_baseline = 1;
            xlabel('Latitude [deg.]','Interpreter',text_interpreter); ylabel(strcat('SWH',' [m]'),'Interpreter',text_interpreter);
            text_in_textbox=text_in_textbox(~cellfun(@isempty,text_in_textbox));
            xlim([min(data{baseline_HR}.GEO.LAT), max(data{baseline_HR}.GEO.LAT)]);
            ylim([0, 5]);
            h=annotation(gcf, 'textbox',[0.37,0,0.5,0.45],'String',text_in_textbox,...
                'FitBoxToText','on','FontSize',cnf_tool.textbox_fontsize, 'Interpreter',text_interpreter);
            h.LineWidth = 0.5;
            
            
            % SSH
            subplot(2,6,[10,11]);
            legend_text={''};
            text_in_textbox={''};
            plot_baseline = 1;
            for b=1:N_baselines
                coef_width=1*0.6^(plot_baseline-1);
                plot_baseline = plot_baseline + 1;
                plt=plot(lat_surf{b}(1:m),SSH_filtered{b}(1:m),'Marker',cnf_tool.marker_bs{b},'Color',color_bs(b,:),...
                    'LineStyle',cnf_tool.LineStyle{b}, 'MarkerSize', cnf_tool.default_markersize, 'LineWidth', coef_width*cnf_tool.default_linewidth);
                plt.Color(4) = 1; % transparency
                hold on;
                legend_text=[legend_text,name_bs(b)];
        %         text_in_textbox=[text_in_textbox, strcat(char(name_bs(b)), ':'), sprintf('RMSE = %.4g [m]\nstd = %.4g [m]\nBias = %.4g [m]', ...
        %             SSH_RMSE(b), SSH_std_mean(b), nanmean(SSH_mean{b}-bias_compensation)-ref_SSH)];
                text_in_textbox=[text_in_textbox, strcat(char(name_bs(b)), ':'), sprintf('RMSE = %.4g [m]\nstd = %.4g [m]\nmean = %.4g [m]', ...
                    SSH_RMSE(b), SSH_std_mean(b), nanmean(SSH_mean{b}))];
                if b ~= N_baselines
                   text_in_textbox = [text_in_textbox, sprintf('\n')]; 
                end
            end
            set(gca,'Xdir','reverse')
            plot_baseline = 1;
            leg=legend(legend_text(~cellfun(@isempty,legend_text)),'Location','northeast');
            pos_leg=get(leg,'Position');
            xlabel('Latitude [deg.]','Interpreter',text_interpreter); ylabel(strcat('SSH',' [m]'),'Interpreter',text_interpreter);
            text_in_textbox=text_in_textbox(~cellfun(@isempty,text_in_textbox));
            xlim([min(data{baseline_HR}.GEO.LAT), max(data{baseline_HR}.GEO.LAT)]);
            ylim([0, max(SSH_filtered{1})+(5-mod(max(SSH_filtered{1}),5))]);
            h=annotation(gcf, 'textbox',[0.78,0,0.5,0.45],'String',text_in_textbox,...
                'FitBoxToText','on','FontSize',cnf_tool.textbox_fontsize, 'Interpreter',text_interpreter);
            h.LineWidth = 0.5;
            
            % define output filename
            indx_bs = 1:length(name_bs);
            ext_baselines_comp=strjoin(name_bs(indx_bs(indx_bs ~= indx_LR)),'_vs_'); 

            print(print_file,cnf_tool.res_fig,[filesBulk(i_baseline).resultPath,file_id,'_',ext_baselines_comp, '_dynamic_W',num2str(m,'%04.0f'),file_ext]);
            if cnf_tool.save_figure_format_fig
               savefig([filesBulk(i_baseline).resultPath,file_id,'_',ext_baselines_comp, '_dynamic_W',num2str(m,'%04.0f'), '.fig']) 
            end
        end     
        
        close(f1);

        clear plt_meas  plt_anal;
	end
end

end
