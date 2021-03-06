classdef Block < handle
    %Block is a class representing each raw file and its corresponding
    %preprocessed file in data_folder and result_folder respectively.
    %   A Block contains the entire relevant information of each raw file
    %   and its corresponding preprocessed file.
    %   This information include a unique_name for each block, the name of
    %   the raw_file, its extension, its corresponding Subject, the prefix
    %   of the preprocessed file, parameters of preprocessing (for more 
    %   info on the parameters of the preprocessing see preprocess.m) 
    %   , sampling rate of the corresponding project, list of channels
    %   that are chosen to be interpolated, rate of the preprocessed file
    %   given during the rating process in rating_gui, list of channels
    %   interpolated during the preprocessing, list of channels that are
    %   interpolated by manual inspection and a boolean stating whether
    %   this block has been already interpolated or not.
    %
    %   Block is a subclass of handle, meaning it's a refrence to an
    %   object. Use accordingly.
    %
    %Block Methods:
    %   Block - To create a project following arguments must be given:
    %   myBlock = Block(subject, file_name, ext, dsrate, params)
    %   where subject is an instance of class Subject which specifies the
    %   Subject to which this block belongs to, file_name is the name of 
    %   the raw_file corresponding to this block, dsrate is the sampling
    %   rate of the corresponding project with which a reduced file is
    %   obtained and params the parameters of the preprocessing used on
    %   this block.
    %
    %   update_rating_info_from_file_if_any - Check if any corresponding
    %   preprocessed file exists, if it's the case import the rating data
    %   to this block, initialise otherwise.
    %
    %   potential_result_address - Check in the result folder for a
    %   corresponding preprocessed file with any prefix that respects the
    %   standard pattern (See prefix).
    %   
    %   update_addresses - The method is to be called to update addresses
    %   in case the project is loaded from another operating system and may
    %   have a different path to the data_folder or result_folder. This can
    %   happen either because the data is on a server and the path to it is
    %   different on different systems, or simply if the project is loaded
    %   from a windows to an iOS or vice versa. The best practice is to call
    %   this method before accessing a block to make sure it's synchronised
    %   with its project.
    %
    %   setRatingInfoAndUpdate - This method must be called to set and
    %   update the new rating information of this block (For example when 
    %   user changes the rating within the rating_gui).
    %
    %   saveRatingsToFile - Save all rating information to the
    %   corresponding preprocessed file
    %
    % Copyright (C) 2017  Amirreza Bahreini, amirreza.bahreini@uzh.ch
    % 
    % This program is free software: you can redistribute it and/or modify
    % it under the terms of the GNU General Public License as published by
    % the Free Software Foundation, either version 3 of the License, or
    % (at your option) any later version.
    % 
    % This program is distributed in the hope that it will be useful,
    % but WITHOUT ANY WARRANTY; without even the implied warranty of
    % MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    % GNU General Public License for more details.
    % 
    % You should have received a copy of the GNU General Public License
    % along with this program.  If not, see <http://www.gnu.org/licenses/>.

    %% Properties
    properties
        
        % Index of this block in the block list of the project.
        index 
        
        % The address of the corresponding raw file
        source_address
        
        % The address of the corresponding preprocessed file. It has the
        % form /root/project/subject/prefix_unique_name.mat (ie. np_subject1_001).
        result_address
        
        % The address of the corresponding reduced file. The reduced file is
        % a downsampled file of the preprocessed file. Its use is only to be
        % plotted on the rating_gui. It is downsampled to speed up the
        % plotting in rating_gui
        reduced_address
        
        qualityScore
    end

    properties(SetAccess=private)
        
        project
        % Instance of the Subject. The corresponding subject that contains
        % this block.
        subject
        
        % Unique_name of this block. It has the form
        % subjectName_rawFileName (ie. subject1_001).
        unique_name
        
        % Name of the raw file of this block
        file_name
        
        % File extension of the raw file. Could be .raw, .RAW, .dat or .fif
        file_extension
        
        % Downsampling rate of the project. This is used to downsample and
        % obtain the reduced file.
        dsrate
        
        srate 
        
        
        % Parameters of the preprocessing. To learn more please see
        % preprocessing/preprocess.m
        params

        % Prefix of the corresponding preprocessed file. Prefix has the
        % pattern '^[gobni]i?p': It could be any of the following:
        %   np - preprocessed file not rated
        %   gp - preprocessed file rated as Good
        %   op - preprocessed file rated as OK
        %   bp - preprocessed file rated as Bad
        %   ip - preprocessed file rated as Interpolate
        %   nip - preprocessed file not rated but interpoalted at least
        %   once
        %   gip - preprocessed file rated as Good and interpolated at least
        %   once
        %   oip - preprocessed file rated as OK and interpolated at least
        %   once
        %   bip - preprocessed file rated as Bad and interpolated at least
        %   once
        %   iip - preprocessed file rated as Interpolated and interpolated 
        %   at least once
        prefix
        
        % List of the channels chosen by the user in the gui to be 
        % interpolated.
        tobe_interpolated
        
        % rate of this block: Good, Bad, OK, Interpolate, Not Rated
        rate
        
        % List of the channels that have been interpolated by the manual
        % inspection in interpolate_selected. Note that this is not a set,
        % If a channel is interpolated n times, there will be n instances 
        % of this channel in the list.  
        final_badchans
        
        % List of the channels that have been selected as bad channels during
        % the preprocessing. Note that they are not necessarily interpolated.
        auto_badchans
        
        % is true if the block has been already interpolated at least once.
        is_interpolated
        
        is_manually_rated
        
        slash
        
        CGV
    end
    
    properties(Dependent)
        
        % The address of the plots obtained during the preprocessing
        image_address
    end
    
    %% Constructor
    methods   
        function self = Block(project, subject, file_name)
  
            self.CGV = ConstantGlobalValues;
            
            self.project = project;
            self.subject = subject;
            self.file_name = file_name;
            
            self.file_extension = project.file_extension;
            self.dsrate = project.dsrate;
            self.params = project.params;
            self.srate = project.srate;
            
            
            self.unique_name = self.extract_unique_name(subject, file_name);
            self.source_address = self.extract_source_address(subject, ...
                file_name, self.file_extension);
            self = self.update_rating_info_from_file_if_any();
        end
    end
    
    %% Public Methods
    methods
        
        function self = update_rating_info_from_file_if_any(self)
            % Check if any corresponding preprocessed file exists, if it's 
            % the case and that file has been already rated import the 
            % rating data to this block, initialise otherwise.
            
            if( exist(self.potential_result_address(), 'file'))
                preprocessed = matfile(self.potential_result_address());
                automagic = preprocessed.automagic;
                
                aut_params = automagic.params;
                aut_fields = fieldnames(aut_params);
                idx = ismember(aut_fields, fieldnames(self.params));
                aut_params = struct2cell(aut_params);
                aut_params = cell2struct(aut_params(idx), aut_fields(idx));
                if( ~ isequal(aut_params, self.params))
                    msg = ['Preprocessing parameters of the ',...
                        self.file_name, ' does not correspond to', ... 
                        'the preprocessing parameters of this '
                        'project. This file can not be merged.'];
                    popup_msg(msg, 'Error');
                    ME = MException('Automagic:Block:parameterMismatch', msg);
                    throw(ME);
                end 
            end
            % Find the preprocessed file if any (empty char if there is no
            % file).
            extracted_prefix = self.extract_prefix(...
                self.potential_result_address());
            
            % If the prefix indicates that the block has been already rated
            if(self.has_information(extracted_prefix))
                preprocessed = matfile(self.potential_result_address());
                automagic = preprocessed.automagic;
                self.rate = automagic.rate;
                self.tobe_interpolated = automagic.tobe_interpolated;
                self.is_interpolated = (length(extracted_prefix) == 3);
                self.auto_badchans = automagic.auto_badchans;
                self.final_badchans = automagic.final_badchans;
                self.qualityScore = automagic.qualityScore;
                self.is_manually_rated = automagic.is_manually_rated;
            else
                self.rate = ConstantGlobalValues.ratings.NotRated;
                self.tobe_interpolated = [];
                self.auto_badchans = [];
                self.final_badchans = [];
                self.is_interpolated = false;
                self.qualityScore = nan;
                self.is_manually_rated = 1;
            end
            
            % Build prefix and adress based on ratings
            self = self.update_prefix_and_result_address();
        end
        
        function result_address = potential_result_address(self)
            % Check in the result folder for a
            % corresponding preprocessed file with any prefix that respects 
            % the standard pattern (See prefix).
   
            pattern = '^[gobni]i?p_';
            fileData = dir(strcat(self.subject.result_folder, self.slash));                                        
            fileNames = {fileData.name};  
            idx = regexp(fileNames, strcat(pattern, self.file_name, '.mat')); 
            inFiles = fileNames(~cellfun(@isempty,idx));
            assert(length(inFiles) <= 1);
            if(~ isempty(inFiles))
                result_address = strcat(self.subject.result_folder, ...
                    self.slash, inFiles{1});
            else
                result_address = '';
            end
        end
       
        function self = update_addresses(self, new_data_path, ...
                new_project_path)
            % The method is to be called to update addresses
            % in case the project is loaded from another operating system and may
            % have a different path to the data_folder or result_folder. This can
            % happen either because the data is on a server and the path to it is
            % different on different systems, or simply if the project is loaded
            % from a windows to a iOS or vice versa. 

            self.subject = self.subject.update_addresses(new_data_path, ...
                new_project_path);
            self.source_address = ...
                self.extract_source_address(self.subject, self.file_name,...
                self.file_extension);
            self = self.update_prefix_and_result_address();
        end
        
        function self = setRatingInfoAndUpdate(self, updates)
            % Set the new rating information
            % Here 'rate' will be overwritten to Interpolate if channels
            % are given to tobe_interpolated
            % is_manally_rated will be overwritten to the reality even if
            % it is given by a param
            % Check consistency of rate and tobe_interpolated
            % final_badchans will append if list is not empty, otherwise
            % makes it empty
            if isfield(updates, 'qualityScore')
                self.qualityScore  = updates.qualityScore;
            end
            
            if isfield(updates, 'rate')
                self.rate = updates.rate;
                self.is_manually_rated = ~ strcmp(updates.rate, ...
                    rateQuality(self.qualityScore, self.project.qualityCutoffs));
                if ~ strcmp(self.rate, self.CGV.ratings.Interpolate)
                    if ~ isfield(updates, 'tobe_interpolated')
                        % If new rate is not Interpolate and no (empty) list 
                        % of interpolation is given then make the list empty
                        self.tobe_interpolated = [];
                    end
                end
                
            end
            
            if isfield(updates, 'tobe_interpolated')
                self.tobe_interpolated = updates.tobe_interpolated;
                if ~ isempty(updates.tobe_interpolated)
                    self.rate = self.CGV.ratings.Interpolate;
                else
                    % This can happen when user removes the interpolation
                    % channel while choosing them
                end
            end
            
            if isfield(updates, 'final_badchans')
                if isempty(updates.final_badchans)
                    self.final_badchans = updates.final_badchans;
                else
                    self.final_badchans = ...
                        [self.final_badchans, updates.final_badchans]; 
                end
            end
            
            if isfield(updates, 'is_interpolated')
                self.is_interpolated = updates.is_interpolated;
            end
            
            % Update the result address and rename if necessary
            self = self.update_prefix_and_result_address();
            
            % Update the rating list structure of the project
            self.project.update_rating_lists(self);
        end
        
        function [EEG, automagic] = preprocess(self)
            % Load the file
            data = self.load_eeg_from_file();

            if(any(strcmp({self.CGV.extensions.fif}, self.file_extension))) 
                self.params.original_file = self.source_address;
            end

            % Preprocess the file
            [EEG, fig1, fig2] = preprocess(data, self.params);

            if(any(strcmp({self.CGV.extensions.fif}, self.file_extension))) 
                self.params = rmfield(self.params, 'original_file');
            end
            
            % If there was an error
            if(isempty(EEG))
                return;
            end
            qScore  = calcQuality(EEG, unique(self.final_badchans), ...
                self.project.qualityThresholds); 
            qRate = rateQuality(qScore, self.project.qualityCutoffs);
            
            self.setRatingInfoAndUpdate(struct('rate', qRate, ...
                'tobe_interpolated', EEG.automagic.auto_badchans, ...
                'final_badchans', [], 'is_interpolated', false, ...
                'qualityScore', qScore));
            
            
            automagic = EEG.automagic;
            EEG = rmfield(EEG, 'automagic');
            
            automagic.tobe_interpolated = automagic.auto_badchans;
            automagic.final_badchans = self.final_badchans;
            automagic.is_interpolated = self.is_interpolated;
            automagic.version = self.CGV.version;
            automagic.qualityScore = self.qualityScore;
            automagic.rate = self.rate;
            automagic.is_manually_rated = self.is_manually_rated;
            self.saveFiles(EEG, automagic, fig1, fig2);
        end
        
        function interpolate(self)
            % Interpolate and save to results
            preprocessed = matfile(self.result_address,'Writable',true);
            EEG = preprocessed.EEG;
            automagic = preprocessed.automagic;
            
            interpolate_chans = self.tobe_interpolated;
            if(isempty(interpolate_chans))
                popup_msg(['The subject is rated to be interpolated but no',...
                    'channels has been chosen.'], 'Error');
                return;
            end
            
            % Put NaN channels to zeros so that interpolation works
            nanchans = find(all(isnan(EEG.data), 2));
            EEG.data(nanchans, :) = 0;

            EEG = eeg_interp(EEG ,interpolate_chans , ...
                self.params.interpolation_params.method);

            qScore  = calcQuality(EEG, ...
                unique([self.final_badchans interpolate_chans]), ...
                self.project.qualityThresholds); 
            qRate = rateQuality(qScore, self.project.qualityCutoffs);

            % Put the channels back to NaN if they were not to be interpolated
            % originally
            original_nans = setdiff(nanchans, interpolate_chans);
            EEG.data(original_nans, :) = NaN;

            % Downsample the new file and save it
            reduced.data = (downsample(EEG.data', self.dsrate))'; %#ok<STRNU>
            save(self.reduced_address, ...
                self.CGV.preprocessing_constants ...
                .general_constants.reduced_name, '-v6');

            % Setting the new information
            self.setRatingInfoAndUpdate(struct('rate', qRate, ...
                'tobe_interpolated', [], ...
                'final_badchans', interpolate_chans, ...
                'is_interpolated', true, ...
                'qualityScore', qScore));
            
            automagic.interpolation.channels = interpolate_chans;
            automagic.interpolation.params = self.params.interpolation_params;
            automagic.qualityScore = self.qualityScore;
            automagic.rate = self.rate;
            
            preprocessed = matfile(self.result_address,'Writable',true);
            preprocessed.EEG = EEG;
            preprocessed.automagic = automagic;
            self.saveRatingsToFile();
        end
        
        function saveFiles(self, EEG, automagic, fig1, fig2) %#ok<INUSL>
            % Save results of preprocessing
            
            % Delete old results
            if( exist(self.reduced_address, 'file' ))
                delete(self.reduced_address);
            end
            if( exist(self.result_address, 'file' ))
                delete(self.result_address);
            end
            if( exist([self.image_address, '.tif'], 'file' ))
                delete([self.image_address, '.tif']);
            end
            
            % save results
            set(fig1,'PaperUnits','inches','PaperPosition',[0 0 10 8])
            print(fig1, self.image_address, '-djpeg', '-r200');
            close(fig1);
            print(fig2, strcat(self.image_address, '_orig'), '-djpeg', '-r100');
            close(fig2);

            reduced.data = downsample(EEG.data',self.dsrate)'; %#ok<STRNU>
            fprintf('Saving results...\n');
            save(self.reduced_address, ...
                self.CGV.preprocessing_constants...
                .general_constants.reduced_name, ...
                '-v6');
            save(self.result_address, 'EEG', 'automagic','-v7.3');
        end
        
        function saveRatingsToFile(self)
            % Save all rating information to the corresponding preprocessed 
            % file
            
            preprocessed = matfile(self.result_address,'Writable',true);
            automagic = preprocessed.automagic;
            automagic.tobe_interpolated = self.tobe_interpolated;
            automagic.rate = self.rate;
            automagic.auto_badchans = self.auto_badchans;
            automagic.is_interpolated = self.is_interpolated;
            automagic.is_manually_rated = self.is_manually_rated;
            automagic.qualityScore = self.qualityScore;
            
            % It keeps track of the history of all interpolations.
            automagic.final_badchans = self.final_badchans;
            preprocessed.automagic = automagic;
        end
        
        function slash = get.slash(self) %#ok<MANU>
            if(isunix)
                slash = '/';
            elseif(ispc)
                slash = '\';
            end
        end
        
        function img_address = get.image_address(self)
            % The name and address of the obtained plots during
            % preprocessing
           img_address = [self.subject.result_folder self.slash self.file_name];
        end
        
        function bool = is_interpolate(self)
            % Return to true if this block is rated as Interpolate
            bool = strcmp(self.rate, ConstantGlobalValues.ratings.Interpolate);
            bool = bool &&  (~ self.is_null);
        end
        
        function bool = is_good(self)
            % Return to true if this block is rated as Good
            bool = strcmp(self.rate, ConstantGlobalValues.ratings.Good);
            bool = bool &&  (~ self.is_null);
        end
        
        function bool = is_ok(self)
            % Return to true if this block is rated as OK
            bool = strcmp(self.rate, ConstantGlobalValues.ratings.OK);
            bool = bool &&  (~ self.is_null);
        end
        
        function bool = is_bad(self)
            % Return to true if this block is rated as Bad
            bool = strcmp(self.rate, ConstantGlobalValues.ratings.Bad);
            bool = bool &&  (~ self.is_null);
        end
        
        function bool = is_not_rated(self)
            % Return to true if this block is rated as Not Rated
            bool = strcmp(self.rate, ConstantGlobalValues.ratings.NotRated);
            bool = bool &&  (~ self.is_null);
        end
        
        function bool = is_null(self)
            % Return true if this block is a mock block
            bool = (self.index == -1);
        end
    end
    
    %% Private Methods
    methods(Access=private)

        function data = load_eeg_from_file(self)
            % Case of .mat file
            if( any(strcmp(self.file_extension(end-3:end), ...
                    {self.CGV.extensions.mat})))
                data = load(self.source_address);
                data = data.EEG;
                
            % case if .txt file
            elseif(any(strcmp(self.file_extension, ...
                    {self.CGV.extensions.text})))
                [~, data] = ...
                    evalc(['pop_importdata(''dataformat'',''ascii'',' ...
                    '''data'', self.source_address,''srate'', self.srate,' ...
                    '''pnts'',0,''xmin'',0)']);
            else
                [~ , data] = evalc('pop_fileio(self.source_address)');
            end 
        end
        
        function self = update_prefix(self)
            % Update the prefix based in the rating information. This must 
            % be set after rating info are set. See the below function.
            p = 'p';
            if (self.is_interpolated)
                i = 'i';
            else
                i = '';
            end
            r = lower(self.rate(1));
            self.prefix = strcat(r, i, p);
        end

        function self = update_prefix_and_result_address(self)
            % Update prefix and thus addresses based on the rating
            % information. This must be called once rating info are set. 
            % Then the address and prefix are set based on rating info.
            self = self.update_prefix();
            self.result_address = strcat(self.subject.result_folder, ...
                self.slash, self.prefix, '_', self.file_name, '.mat');
            self.reduced_address = self.extract_reduced_address(...
                self.result_address, self.dsrate);
            
            % Rename the file if it doesn't correspond to the actual rating
            if( ~ strcmp(self.result_address, self.potential_result_address))
                if( ~ isempty(self.potential_result_address) )
                    movefile(self.potential_result_address, ...
                        self.result_address);
                end
            end
        end
        
        function source_address = extract_source_address(self, subject, ...
                file_name, ext)
            % Return the address of the raw file
            source_address = [subject.data_folder self.slash file_name, ext];
        end
        
        function prefix = extract_prefix(self, result_address)
            % Given the result_address, take the prefix out of it and
            % return. If results_adsress = '', then returns prefix = ''. 
            splits = strsplit(result_address, self.slash);
            name_with_ext = splits{end};
            splits = strsplit(name_with_ext, '.');
            prefixed_name = splits{1};
            splits = strsplit(prefixed_name, '_');
            prefix = splits{1};
            
            if( ~ Block.is_valid_prefix(prefix) )
                popup_msg('Not a valid prefix.','Error');
                return;
            end
        end
    end
    
    %% Private utility static methods
    methods(Static, Access=private)
        
        function reduced_address = extract_reduced_address(...
                result_address, dsrate)
            % Return the address of the reduced file
            
            pattern = '[gobni]i?p_';
            reduced_address = regexprep(result_address,pattern,...
                strcat('reduced', int2str(dsrate), '_'));
        end
        
        function unique_name = extract_unique_name(subject, file_name)
            % Return the unique_name of this block. The unique_name is the
            % concatenation of the subject's name and this raw file's name
            
            unique_name = strcat(subject.name, '_', file_name);
        end

        function bool = has_information(prefix)
            % Return true if the prefix indicates that this preprocessed
            % file has been already rated.
            
            bool = true;
            
            % If the length is 3, there must be an "i" in it, which
            % indicates it's already been rated and interpolated.
            if(length(prefix) == 3)
                return;
            end
            
            switch Block.get_rate_from_prefix(prefix)
                case ConstantGlobalValues.ratings.NotRated
                    bool = false;
                case ''
                    bool = false;
            end
        end
        
        function type = get_rate_from_prefix(prefix)
            % Extract the rating information from the prefix. The first
            % character of the prefix indicates the rating. 
            
            if( strcmp(prefix, ''))
                type = ConstantGlobalValues.ratings.NotRated;
                return;
            end
            
            type = '';
            switch prefix(1)
                case 'g'
                    type = ConstantGlobalValues.ratings.Good;
                case 'o'
                    type = ConstantGlobalValues.ratings.OK;
                case 'b'
                    type = ConstantGlobalValues.ratings.Bad;
                case 'i'
                    type = ConstantGlobalValues.ratings.Interpolate;
                case 'n'
                    type = ConstantGlobalValues.ratings.NotRated;
            end
        end

        function bool = is_valid_prefix(prefix)
            % Return true if the prefix respects the standard pattern
            
            pattern = '^[gobni]i?p$';
            reg = regexp(prefix, pattern, 'match');
            bool = ~ isempty(reg) || strcmp(prefix, '');
        end
        

    end
    
end

