function regressed = EOG_regression(EEG, EOG)
% EOG_regression  perform EOG regression from EOG channels
%   Both EEG and EOG are EEGLAB data structure.
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

constants = PreprocessingConstants.eog_regression_constants;
display(constants.run_message);

eeg = EEG.data';
eog = EOG.data';

eegclean =  eeg - eog * (eog \ eeg);


regressed = EEG;
regressed.data = eegclean';

% Write back what has happened
regressed.automagic.eog_regression.performed = 'yes';
regressed.automagic.eog_regression.eog_channels = EOG.chanlocs;
end