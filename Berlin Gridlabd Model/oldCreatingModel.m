clear all;
format long g;

%% Most of the things you might want to change via a scripting mechanism are located in this section

% Directory for input files (CSVs)
% dir = '~\Anwendung\gridlabd\tools\IEEETest\4800Bus\CSV_Version';
% Directory for output of GLM files
dir2 = 'TestModel.glm';

% Power flow solver method
solver_method = 'NR';

% Start and stop times
start_date='''2012-04-08';
stop_date  = '''2014-04-08';
start_time='00:00:00''';
stop_time = '17:00:00''';
% timezone='PST+8PDT';

% Do you want to use houses?
houses = 'y';   % 'y' indicates you want to use houses, 'n' indicates static loads
use_load = 'y'; % 'y' indicates you want zip loads, 'n' indicates no "appliances" within the home
% climate_file = 'WA-Yakima.tmy2';

load_scalar = 1.0;   % leave as 1 for house models; if houses='n', then this scales the base load of the original 8500 node system
house_scalar = 6;  % changes square ft (an increase in house_scalar will decrease sqft and decrease load)
zip_scalar = 3;   % scales the zip load (an increase in zip_scalar will increase load)

gas_perc = 0.2; % percent of homes that use gas heat (rest use resistive)
elec_cool_perc = 0.8; % percent of homes that use electric AC (rest use NONE)

perc_gas_wh = 0; % percent of homes with gas waterheaters (rest use electrical)

with_DR = 0; % do we want to include DR;
             %   case 0 = NONE
             %   case 1 = all OFF as driven by price.player
             
% Voltage regulator and capacitor settings
%  All voltages in on 120 volt "per unit" basis
%  VAr setpoints for capacitors are in kVAr
%  Time is in seconds

% Regulator bandcenter voltage, bandwidth voltage, time delay
reg = [7500/60, 2,  60;  % VREG1 (at feeder head)
       7470/60, 2, 120;  % VREG2 (cascaded reg on north side branch, furthest down circuit)
       7440/60, 2,  75;  % VREG3 (cascaded reg on north side branch, about halfway up circuit before VREG2)
       7380/60, 2,  90]; % VREG4 (solo reg on south side branch)
     
% Capacitor voltage high, voltage low, kVAr high, kVAr low, time delay
% - Note, Cap0-Cap2 are in VOLTVAR control mode, Cap3 is in MANUAL mode
% -- (Cap3 is on south side branch after VREG 4)
cap = [130, 115.5, 375, -250, 480;  % CapBank0 (right before VREG2, but after VREG3)
       130, 115.5, 325, -250, 300;  % CapBank1 (a little after substation, before VREG3 or VREG4))
       130, 115.5, 350, -250, 180]; % CapBank2 (at substation)


%%  Power factor and ZIP settings for each ZIP load %%
% Lights
light_type = 'OTHER';
if (strcmp(light_type,'INCANDESCENT'))
    avg_lights = 1;          % normal distribution clipped at 0.5 and 2 kW
    std_dev_lights = 0.2;    % represents total AVAILABLE light load - schedule uses 20-50 perc of this 
    lights_pwr_frac = 0.0032;
    lights_curr_frac = 0.4257;
    lights_imp_frac = 0.5711;
    lights_pwr_pf = 1;
    lights_curr_pf = -1;
    lights_imp_pf = 1;
else
    avg_lights = .25;        % normal distribution clipped at .1 and .4 kW
    std_dev_lights = 0.05;   % represents total AVAILABLE light load - schedule uses 20-50 perc of this 
    lights_pwr_frac = 0.5849;
    lights_curr_frac = 0.0067;
    lights_imp_frac = 0.4085;
    lights_pwr_pf = -0.78;
    lights_curr_pf = 0.42;
    lights_imp_pf = -0.88;
end

% Plugs
avg_plug = 0.075;          % normal distribution clipped at 0.05 and .5 kW
std_dev_plug = 0.02;      
plug_pwr_frac = 0.1;
plug_curr_frac = 0.1;
plug_imp_frac = 0.8;
plug_pwr_pf = 0.95;
plug_curr_pf = 0.95;
plug_imp_pf = 0.95;

% Fan
avg_fan = 0.075;          % normal distribution clipped at 0.05 and .5 kW
std_dev_fan = 0.02;      
fan_pwr_frac = 0.0135;
fan_curr_frac = 0.2534;
fan_imp_frac = 0.7332;
fan_pwr_pf = -1;
fan_curr_pf = 0.95;
fan_imp_pf = 0.97;

% CRT TV
avg_crt_tv = 0.075;          % normal distribution clipped at 0.025 and .125 kW
std_dev_crt_tv = 0.02;      
crt_tv_pwr_frac = 0.1719;
crt_tv_curr_frac = 0.8266;
crt_tv_imp_frac = 0.0015;
crt_tv_pwr_pf = -0.92;
crt_tv_curr_pf = 1;
crt_tv_imp_pf = -0.99;

% LCD TV
avg_lcd_tv = 0.125;          % normal distribution clipped at 0.025 and .4 kW
std_dev_lcd_tv = 0.05;      
lcd_tv_pwr_frac = 0.9987;
lcd_tv_curr_frac = 0.0396;
lcd_tv_imp_frac = -0.0383;
lcd_tv_pwr_pf = -1;
lcd_tv_curr_pf = -0.54;
lcd_tv_imp_pf = 0.61;

lcd_to_crt = 0.8;  % 80 percent lcd

%% Some nominal voltage stuff for assigning flat start voltages
nom_volt1 = '7199.558';
nom_volt2 = '12470.00';
nom_volt3 = '69715.05';
nom_volt4 = '115000.00';


%% Load Lines.csv values

% Name1|From node2|Phases3|to node4|Phases5|Length6|Units7|Config8|Status9
fidLines = fopen('Lines.csv');
%Header1Lines = textscan(fidLines,'%s',1);
Header2Lines = textscan(fidLines,'%s %s %s %s %s %s %s %s ',1,'Delimiter',',');

RawLines = textscan(fidLines,'%s %s %s %s %s %n %s %s ','Delimiter',',');

% Load Transformers.csv values
% Name1|Phases2|From3|To4|primV5|secV6|MVA7|PrimConn8|SecConn9|%X10|%R11
fidTrans = fopen('Transformers.csv');
Header1Trans = textscan(fidTrans,'%s',1);
Header2Trans = textscan(fidTrans,'%s %s %s %s %s %s %s %s %s %s %s',2,'Delimiter',',');

RawTrans = textscan(fidTrans,'%s %n %s %s %n %n %n %s %s %n %n','Delimiter',',');

% Load LoadXfmrs.csv values
% Name1|#ofPhases2|From3|Phase4|PrimkV5|PrimkVA6|ToPh1-7|Ph1-8|SeckVPh1-9|
% SeckVAPh1-10|ToPh2-11|Ph2-12|SeckVPh2-13|SeckVAPh2-14|imag-15|R1-16|
% R2-17|R3-18|NoLoad-19|X12-20|X13-21|X23-22
fidLoadTrans = fopen('LoadXfmrs.csv');
Header1LoadTrans = textscan(fidLoadTrans,'%s',1);
Header2LoadTrans = textscan(fidLoadTrans,'%s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %s',2,'Delimiter',',');

RawLoadTrans = textscan(fidLoadTrans,'%s %n %s %s %n %n %s %s %n %n %s %s %n %n %n %n %n %n %n %n %n %n','Delimiter',',');

% Load Triplex_Lines.csv values
% Name1|From2|Phases3|To4|Phases5|LineConf6|Length7|Units8
fidTripLines = fopen('Triplex_Lines.csv');
Header1TripLines = textscan(fidTripLines,'%s',14);
Header2TripLines = textscan(fidTripLines,'%s',10);
Header3TripLines = textscan(fidTripLines,'%s',16);
Header4TripLines = textscan(fidTripLines,'%s %s %s %s %s %s %s %s',1,'Delimiter',',');

RawTripLines = textscan(fidTripLines,'%s %s %s %s %s %s %n %s','Delimiter',',');

% Load Loads.csv values
% Name1|#ofPh|NameofBus3|Ph4|NomVolt5|Status6|Model7|Connect8|Power9|PF10
fidTripLoads = fopen('Loads.CSV');
Header1TripLoads = textscan(fidTripLoads,'%s',12);
Header2TripLoads = textscan(fidTripLoads,'%s',8);
Header3TripLoads = textscan(fidTripLoads,'%s',11);
Header4TripLoads = textscan(fidTripLoads,'%s',10);
Header5TripLoads = textscan(fidTripLoads,'%s %s %s %s %s %s %s %s %s %s',1,'Delimiter',',');

RawTripLoads = textscan(fidTripLoads,'%s %n %s %s %n %s %n %s %n %n','Delimiter',',');

fidcond = fopen('WireData.dss');
Header1 = textscan(fidcond,'%s',4);

% Values{1}-name | {2}-ohms/km | {3}-GMR in cm | {4}-outer rad? (cm)
CondValues = textscan(fidcond,'%*s WireData.%s Rac=%n %*s GMRac=%n %*s Radius=%n %*s %*s %s');

Racunits = 'Ohm/km';
GMRunits = 'cm';

fclose('all');

NameLines = char(RawLines{1});
FromLines = char(RawLines{2});
PhasesLines = char(RawLines{3});
ToLines = char(RawLines{4});
LengthLines = (RawLines{6});
UnitLines = char(RawLines{7});
ConfigLines = char(RawLines{8});
% StatusLines = char(RawLines{9});

% EndLines = length(NameLines);
EndLines = 112;
EndLoadTrans = length(RawLoadTrans{1});
EndTripLines = length(RawTripLines{1});
EndTripLoads = length(RawTripLoads{1});
EndTripNodes = length(RawTripLines{1});

%% Print to glm file
if strcmp(solver_method,'FBS')
    if (with_DR ~= 0)
        open_name = [dir2 '\IEEE_8500node_whouses_FBS_DR.glm'];
    else
        open_name = [dir2 '\IEEE_8500node_whouses_FBS.glm'];
    end
elseif strcmp(solver_method,'NR')
    if (with_DR ~= 0)
        open_name = [dir2 '\IEEE_8500node_whouses_NR_DR.glm'];
    else
        open_name = [dir2 '\IEEE_8500node_whouses_NR.glm'];
    end
else
    fprintf('screw-up in naming of open file');
end

fid = fopen(open_name,'wt');

%% Header stuff and schedules
fprintf(fid,'//IEEE 8500 node test system.\n');
fprintf(fid,'//  Generated %s using Matlab %s.\n\n',datestr(clock),version);

fprintf(fid,'clock {\n');
% fprintf(fid,'     timezone %s;\n',timezone);
fprintf(fid,'     starttime %s %s;\n',start_date,start_time);
fprintf(fid,'     stoptime %s %s;\n',stop_date,stop_time);
fprintf(fid,'}\n\n');


%%
fprintf(fid,'module powerflow {\n');
fprintf(fid,'    solver_method %s;\n',solver_method);
fprintf(fid,'    line_limits FALSE;\n');
fprintf(fid,'    default_maximum_voltage_error 1e-4;\n');
fprintf(fid,'};\n');
if (strcmp(houses,'y') ~= 0)
    fprintf(fid,'module residential {\n');
    fprintf(fid,'     implicit_enduses NONE;\n');
    fprintf(fid,'}\n');
    fprintf(fid,'module climate;\n');
end
fprintf(fid,'module tape;\n\n');
% fprintf(fid,'#include "recorders.glm";\n');
% fprintf(fid,'#include "schedules.glm";\n\n');

if (strcmp(houses,'y') ~= 0)
    fprintf(fid,'#set minimum_timestep=1800;\n');
end
fprintf(fid,'#set profiler=1;\n');
fprintf(fid,'#set relax_naming_rules=1;\n');
fprintf(fid,'#set suppress_repeat_messages=1;\n');
fprintf(fid,'#set savefile="8500_balanced_%s.xml";\n',solver_method);

% if (strcmp(houses,'y') ~= 0)
%     fprintf(fid,'object climate {\n');
%     fprintf(fid,'     name "climate";\n');
%     fprintf(fid,'     tmyfile "%s";\n',climate_file);
%     fprintf(fid,'     interpolate QUADRATIC;\n');
%     fprintf(fid,'}\n\n');
% end

if (with_DR ~= 0)
    fprintf(fid,'module market;\n\n');
    
    fprintf(fid,'class auction {\n');
    fprintf(fid,'     double my_avg;\n');
    fprintf(fid,'     double my_std;\n');
    fprintf(fid,'}\n\n');

    fprintf(fid,'object auction {\n');
    fprintf(fid,'     name Market_1;\n');
    fprintf(fid,'     period 4;\n');
    fprintf(fid,'     special_mode BUYERS_ONLY;\n');
    fprintf(fid,'     unit kW;\n');
    fprintf(fid,'     my_avg 1;\n');
    fprintf(fid,'     my_std 1;\n');
    fprintf(fid,'     object player {\n');
    fprintf(fid,'          file price_player.player;\n');
    fprintf(fid,'          property current_market.clearing_price;\n');
    fprintf(fid,'     };\n');
    fprintf(fid,'};\n\n');
    
end

%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Create Regulator objects -- Easiest by hand
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% fprintf(fid,'// Regulators and regulator configurations\n\n');
% 
%  fprintf(fid,'object regulator_configuration {\n');
%  fprintf(fid,'     connect_type 1;\n');
%  fprintf(fid,'     name reg_config_1;\n');
%  if strcmp(solver_method,'FBS')
% %     fprintf(fid,'     Control LINE_DROP_COMP;\n');
% %     fprintf(fid,'     band_center %.1f;\n',reg(1,1));
% %     fprintf(fid,'     band_width %.1f;\n',reg(1,2));
% %     fprintf(fid,'     current_transducer_ratio 0;\n');
% %     fprintf(fid,'     power_transducer_ratio 60.0;\n');
% %     fprintf(fid,'     compensator_r_setting_A 0.0;\n');
% %     fprintf(fid,'     compensator_x_setting_A 0.0;\n');
% %     fprintf(fid,'     compensator_r_setting_B 0.0;\n');
% %     fprintf(fid,'     compensator_x_setting_B 0.0;\n');
% %     fprintf(fid,'     compensator_r_setting_C 0.0;\n');
% %     fprintf(fid,'     compensator_x_setting_C 0.0;\n');
%  elseif strcmp(solver_method,'NR')
%      fprintf(fid,'     Control OUTPUT_VOLTAGE;\n');
%      fprintf(fid,'     band_center %4.1f;\n',reg(1,1)*60);
%      fprintf(fid,'     band_width %3.1f;\n',reg(1,2)*60);
%  end
% else
%     fprintf('Uh-oh, screw up in regulators - possibly unknown type of solver');
% end
% fprintf(fid,'     time_delay %.1f;\n',reg(1,3));
% fprintf(fid,'     raise_taps 16;\n');
% fprintf(fid,'     lower_taps 16;\n');
% fprintf(fid,'     regulation 0.1;\n');
% fprintf(fid,'     Type B;\n');
% fprintf(fid,'}\n\n');

% fprintf(fid,'object regulator_configuration {\n');
% fprintf(fid,'     connect_type 1;\n');
% fprintf(fid,'     name reg_config_2;\n');
% if strcmp(solver_method,'FBS')
%     fprintf(fid,'     Control LINE_DROP_COMP;\n');
%     fprintf(fid,'     band_center %.1f;\n',reg(2,1));
%     fprintf(fid,'     band_width %.1f;\n',reg(2,2));
%     fprintf(fid,'     current_transducer_ratio 0;\n');
%     fprintf(fid,'     power_transducer_ratio 60.0;\n');
%     fprintf(fid,'     compensator_r_setting_A 0.0;\n');
%     fprintf(fid,'     compensator_x_setting_A 0.0;\n');
%     fprintf(fid,'     compensator_r_setting_B 0.0;\n');
%     fprintf(fid,'     compensator_x_setting_B 0.0;\n');
%     fprintf(fid,'     compensator_r_setting_C 0.0;\n');
%     fprintf(fid,'     compensator_x_setting_C 0.0;\n');
% elseif strcmp(solver_method,'NR')
%     fprintf(fid,'     Control OUTPUT_VOLTAGE;\n');
%     fprintf(fid,'     band_center %4.1f;\n',reg(2,1)*60);
%     fprintf(fid,'     band_width %3.1f;\n',reg(2,2)*60);
% else
%     fprintf('Uh-oh, screw up in regulators - possibly unknown type of solver');
% end
% fprintf(fid,'     time_delay %.1f;\n',reg(2,3));
% fprintf(fid,'     raise_taps 16;\n');
% fprintf(fid,'     lower_taps 16;\n');
% fprintf(fid,'     regulation 0.1;\n');
% fprintf(fid,'     Type B;\n');  
% fprintf(fid,'}\n\n');
% 
% fprintf(fid,'object regulator_configuration {\n');
% fprintf(fid,'     connect_type 1;\n');
% fprintf(fid,'     name reg_config_3;\n');
% if strcmp(solver_method,'FBS')
%     fprintf(fid,'     Control LINE_DROP_COMP;\n');
%     fprintf(fid,'     band_center %.1f;\n',reg(3,1));
%     fprintf(fid,'     band_width %.1f;\n',reg(3,2));
%     fprintf(fid,'     current_transducer_ratio 0;\n');
%     fprintf(fid,'     power_transducer_ratio 60.0;\n');
%     fprintf(fid,'     compensator_r_setting_A 0.0;\n');
%     fprintf(fid,'     compensator_x_setting_A 0.0;\n');
%     fprintf(fid,'     compensator_r_setting_B 0.0;\n');
%     fprintf(fid,'     compensator_x_setting_B 0.0;\n');
%     fprintf(fid,'     compensator_r_setting_C 0.0;\n');
%     fprintf(fid,'     compensator_x_setting_C 0.0;\n');
% elseif strcmp(solver_method,'NR')
%     fprintf(fid,'     Control OUTPUT_VOLTAGE;\n');
%     % Changed from 125*60 to 123*60
%     fprintf(fid,'     band_center %4.1f;\n',reg(3,1)*60);
%     fprintf(fid,'     band_width %3.1f;\n',reg(3,2)*60);
% else
%     fprintf('Uh-oh, screw up in regulators - possibly unknown type of solver');
% end
% fprintf(fid,'     time_delay %.1f;\n',reg(3,3));
% fprintf(fid,'     raise_taps 16;\n');
% fprintf(fid,'     lower_taps 16;\n');
% fprintf(fid,'     regulation 0.1;\n');
% fprintf(fid,'     Type B;\n');  
% fprintf(fid,'}\n\n');
% 
% fprintf(fid,'object regulator_configuration {\n');
% fprintf(fid,'     connect_type 1;\n');
% fprintf(fid,'     name reg_config_4;\n');
% if strcmp(solver_method,'FBS')
%     fprintf(fid,'     Control LINE_DROP_COMP;\n');
%     fprintf(fid,'     band_center %.1f;\n',reg(4,1));
%     fprintf(fid,'     band_width %.1f;\n',reg(4,2));
%     fprintf(fid,'     current_transducer_ratio 0;\n');
%     fprintf(fid,'     power_transducer_ratio 60.0;\n');
%     fprintf(fid,'     compensator_r_setting_A 0.0;\n');
%     fprintf(fid,'     compensator_x_setting_A 0.0;\n');
%     fprintf(fid,'     compensator_r_setting_B 0.0;\n');
%     fprintf(fid,'     compensator_x_setting_B 0.0;\n');
%     fprintf(fid,'     compensator_r_setting_C 0.0;\n');
%     fprintf(fid,'     compensator_x_setting_C 0.0;\n');
% elseif strcmp(solver_method,'NR')
%     fprintf(fid,'     Control OUTPUT_VOLTAGE;\n');
%     fprintf(fid,'     band_center %4.1f;\n',reg(4,1)*60);
%     fprintf(fid,'     band_width %3.1f;\n',reg(4,2)*60);
% else
%     fprintf('Uh-oh, screw up in regulators - possibly unknown type of solver');
% end
% fprintf(fid,'     time_delay %.1f;\n',reg(4,3));
% fprintf(fid,'     raise_taps 16;\n');
% fprintf(fid,'     lower_taps 16;\n');
% fprintf(fid,'     regulation 0.1;\n');
% fprintf(fid,'     Type B;\n');  
% fprintf(fid,'}\n\n');
% 
% 
% fprintf(fid,'object regulator {\n');
% fprintf(fid,'     name "FEEDER_REG";\n');
% fprintf(fid,'     phases ABCN;\n');
% fprintf(fid,'     from "regxfmr_HVMV_Sub_LSB";\n');
% fprintf(fid,'     to "_HVMV_Sub_LSB";\n');
% fprintf(fid,'     configuration reg_config_1;\n');
% fprintf(fid,'}\n\n');
% 
% fprintf(fid,'object regulator {\n');
% fprintf(fid,'     name VREG2;\n');
% fprintf(fid,'     phases ABCN;\n');
% fprintf(fid,'     from "regxfmr_190-8593";\n');
% fprintf(fid,'     to "190-8593";\n');
% fprintf(fid,'     configuration reg_config_2;\n');
% fprintf(fid,'}\n\n');
% 
% fprintf(fid,'object regulator {\n');
% fprintf(fid,'     name VREG3;\n');
% fprintf(fid,'     phases ABCN;\n');
% fprintf(fid,'     from "regxfmr_190-8581";\n');
% fprintf(fid,'     to "190-8581";\n');
% fprintf(fid,'     configuration reg_config_3;\n');
% fprintf(fid,'}\n\n');
% 
% fprintf(fid,'object regulator {\n');
% fprintf(fid,'     name VREG4;\n');
% fprintf(fid,'     phases ABCN;\n');
% fprintf(fid,'     from "regxfmr_190-7361";\n');
% fprintf(fid,'     to "190-7361";\n');
% fprintf(fid,'     configuration reg_config_4;\n');
% fprintf(fid,'}\n\n');
%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Create Capacitor objects
%Unsure of the MVAR values for cap3, is it .9 per phase or .9 total?
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% fprintf(fid,'// Capacitors\n\n');
% 
% fprintf(fid,'object capacitor {\n');
% fprintf(fid,'     parent R42246;\n');
% fprintf(fid,'     phases ABCN;\n');
% fprintf(fid,'     pt_phase ABC;\n');
% fprintf(fid,'     name CapBank0;\n');
% fprintf(fid,'     phases_connected ABCN;\n');
% fprintf(fid,'     control VARVOLT;\n');
% fprintf(fid,'     capacitor_A 0.4 MVAr;\n');
% fprintf(fid,'     capacitor_B 0.4 MVAr;\n');
% fprintf(fid,'     capacitor_C 0.4 MVAr;\n');
% fprintf(fid,'     control_level INDIVIDUAL;\n');
% fprintf(fid,'     voltage_set_high %.1f;\n', cap(1,1)*60);
% fprintf(fid,'     voltage_set_low %.1f;\n', cap(1,2)*60);
% fprintf(fid,'     VAr_set_high %.1f kVAr;\n', cap(1,3));
% fprintf(fid,'     VAr_set_low %.1f kVAr;\n', cap(1,4));
% fprintf(fid,'     time_delay %.1f;\n', cap(1,5));
% fprintf(fid,'     lockout_time 1;\n');
% fprintf(fid,'     remote_sense CAP_3;\n');
% fprintf(fid,'     remote_sense_B L2823592_CAP;\n');
% fprintf(fid,'     nominal_voltage %s;\n',nom_volt1);
% fprintf(fid,'}\n\n');
% 
% 
% fprintf(fid,'object capacitor {\n');
% fprintf(fid,'     parent R42247;\n');
% fprintf(fid,'     pt_phase ABC;\n');
% fprintf(fid,'     phases ABCN;\n');
% fprintf(fid,'     name CapBank1;\n');
% fprintf(fid,'     phases_connected ABCN;\n');
% fprintf(fid,'     control VARVOLT;\n');
% fprintf(fid,'     capacitor_A 0.3 MVAr;\n');
% fprintf(fid,'     capacitor_B 0.3 MVAr;\n');
% fprintf(fid,'     capacitor_C 0.3 MVAr;\n');
% fprintf(fid,'     control_level INDIVIDUAL;\n');
% fprintf(fid,'     voltage_set_high %.1f;\n', cap(2,1)*60);
% fprintf(fid,'     voltage_set_low %.1f;\n', cap(2,2)*60);
% fprintf(fid,'     VAr_set_high %.1f kVAr;\n', cap(2,3));
% fprintf(fid,'     VAr_set_low %.1f kVAr;\n', cap(2,4));
% fprintf(fid,'     time_delay %.1f;\n', cap(2,5));
% fprintf(fid,'     remote_sense CAP_2;\n');
% fprintf(fid,'     lockout_time 1;\n');
% fprintf(fid,'     remote_sense_B Q16483_CAP;\n');
% fprintf(fid,'     nominal_voltage %s;\n',nom_volt1);
% fprintf(fid,'}\n\n');
% 
% fprintf(fid,'object capacitor {\n');
% fprintf(fid,'     parent R20185;\n');
% fprintf(fid,'     pt_phase ABC;\n');
% fprintf(fid,'     phases ABCN;\n');
% fprintf(fid,'     name CapBank2;\n');
% fprintf(fid,'     phases_connected ABCN;\n');
% fprintf(fid,'     control VARVOLT;\n');
% fprintf(fid,'     capacitor_A 0.3 MVAr;\n');
% fprintf(fid,'     capacitor_B 0.3 MVAr;\n');
% fprintf(fid,'     capacitor_C 0.3 MVAr;\n');
% fprintf(fid,'     control_level INDIVIDUAL;\n');
% fprintf(fid,'     voltage_set_high %.1f;\n', cap(3,1)*60);
% fprintf(fid,'     voltage_set_low %.1f;\n', cap(3,2)*60);
% fprintf(fid,'     VAr_set_high %.1f kVAr;\n', cap(3,3));
% fprintf(fid,'     VAr_set_low %.1f kVAr;\n', cap(3,4));
% fprintf(fid,'     time_delay %.1f;\n', cap(3,5));
% fprintf(fid,'     lockout_time 1;\n');
% fprintf(fid,'     remote_sense CAP_1;\n');
% fprintf(fid,'     remote_sense_B Q16642_CAP;\n');
% fprintf(fid,'     nominal_voltage %s;\n',nom_volt1);
% fprintf(fid,'}\n\n');
% 
% fprintf(fid,'object capacitor {\n');
% fprintf(fid,'     phases ABCN;\n');
% fprintf(fid,'     parent R18242;\n');
% fprintf(fid,'     name CapBank3;\n');
% fprintf(fid,'     phases_connected ABCN;\n');
% fprintf(fid,'     control MANUAL;\n');
% fprintf(fid,'     capacitor_A 0.3 MVAr;\n');
% fprintf(fid,'     capacitor_B 0.3 MVAr;\n');
% fprintf(fid,'     capacitor_C 0.3 MVAr;\n');
% fprintf(fid,'     control_level INDIVIDUAL;\n');
% fprintf(fid,'     switchA CLOSED;\n');
% fprintf(fid,'     switchB CLOSED;\n');
% fprintf(fid,'     switchC CLOSED;\n');
% fprintf(fid,'     nominal_voltage %s;\n',nom_volt1);
% fprintf(fid,'}\n\n');

%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Create Transformer objects -- only one transformer, so mostly by hand
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

fprintf(fid,'// Transformer and configuration at feeder\n\n');


fprintf(fid,'object transformer_configuration:27500 {\n');
fprintf(fid,'     connect_type DELTA_GWYE;\n');
fprintf(fid,'     name trans_config_1;\n');
fprintf(fid,'     install_type PADMOUNT;\n');
fprintf(fid,'     power_rating %5.0fkVA;\n',1000*RawTrans{7}(1));
fprintf(fid,'     primary_voltage %3.1fkV;\n',RawTrans{5}(1));
fprintf(fid,'     secondary_voltage %2.2fkV;\n',RawTrans{6}(1));
fprintf(fid,'     reactance %1.5f;\n',.01*RawTrans{10}(1));
fprintf(fid,'     resistance %1.5f;\n',.01*RawTrans{11}(1));
fprintf(fid,'}\n\n');

fprintf(fid,'object transformer {\n');
fprintf(fid,'     phases ABCN;\n');
fprintf(fid,'     name "%s";\n',char(RawTrans{1}(1)));
fprintf(fid,'     from "%s";\n',char(RawTrans{3}(1)));
fprintf(fid,'     to "%s";\n',char(RawTrans{4}(1)));
fprintf(fid,'     configuration trans_config_1;\n');
fprintf(fid,'}\n\n');

% One node object in regulators and HV needs to be manually generated
fprintf(fid,'object node {\n');
fprintf(fid,'     phases ABCN;\n');
fprintf(fid,'     name "regxfmr_HVMV_Sub_LSB";\n');
fprintf(fid,'     nominal_voltage %s;\n',nom_volt1);
fprintf(fid,'}\n\n');

fprintf(fid,'object node {\n');
fprintf(fid,'     phases ABCN;\n');
fprintf(fid,'     name "HVMV_Sub_HSB";\n');
fprintf(fid,'     bustype SWING;\n');
fprintf(fid,'     voltage_A 69512-0.7d;\n');    % Correct for missing 
fprintf(fid,'     voltage_B 69557-120.7d;\n');  % reactor
fprintf(fid,'     voltage_C 69595+119.3d;\n');
fprintf(fid,'     nominal_voltage 69512;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object node {\n');
fprintf(fid,'     phases ABCN;\n');
fprintf(fid,'     name "HVMV_Sub_48332";\n');
fprintf(fid,'     nominal_voltage 7199.558;\n');
fprintf(fid,'}\n');
fprintf(fid,'\n');

fprintf(fid,'object regulator {\n');
fprintf(fid,'     name "FEEDER_REG";\n');
fprintf(fid,'     phases ABCN;\n');
fprintf(fid,'     from "regxfmr_HVMV_Sub_LSB";\n');
fprintf(fid,'     to "_HVMV_Sub_LSB";\n');
fprintf(fid,'     configuration reg_config_1;\n');
fprintf(fid,'}\n');
fprintf(fid,'\n');

fprintf(fid,'object regulator_configuration {\n');
fprintf(fid,'     connect_type 1;\n');
fprintf(fid,'     name reg_config_1;\n');
fprintf(fid,'     Control OUTPUT_VOLTAGE;\n');
fprintf(fid,'     band_center 7500.0;\n');
fprintf(fid,'     band_width 120.0;\n');
fprintf(fid,'     time_delay 60.0;\n');
fprintf(fid,'     raise_taps 16;\n');
fprintf(fid,'     lower_taps 16;\n');
fprintf(fid,'     regulation 0.1;\n');
fprintf(fid,'     Type B;\n');
fprintf(fid,'}\n');
fprintf(fid,'\n');




%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Create Center-tap Transformer objects
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

 fprintf(fid,'// Center-tap transformer configurations\n\n');
 
 RHL = 0.006;
 RHT = 0.012;
 RLT = 0.012;
 
 XHL = 0.0204;
 XHT = 0.0204;
 XLT = 0.0136;
 
 XH = 0.5*(XHL+XHT-XLT);
 XL = 0.5*(XHL+XLT-XHT);
 XT = 0.5*(XLT+XHT-XHL);
 
 for i=1:EndLoadTrans
    t_conf = sprintf('%.0f%.0f%s',RawLoadTrans{6}(i),RawLoadTrans{10}(i),char(RawLoadTrans{4}(i))); 
    t_confs(i,1:length(t_conf)) = t_conf;
    if i==1
       fprintf(fid,'object transformer_configuration {\n');
       fprintf(fid,'     name "%s";\n',t_conf);
       fprintf(fid,'     connect_type SINGLE_PHASE_CENTER_TAPPED;\n');
       fprintf(fid,'     install_type POLETOP;\n');
       fprintf(fid,'     primary_voltage %5.1fV;\n',1000*RawLoadTrans{5}(i));
      fprintf(fid,'     secondary_voltage %3.1fV;\n',1000*RawLoadTrans{9}(i));
       fprintf(fid,'     power_rating %2.1fkVA;\n',RawLoadTrans{6}(i));
       fprintf(fid,'     power%s_rating %2.1fkVA;\n',char(RawLoadTrans{4}(i)),RawLoadTrans{10}(i));
       fprintf(fid,'     impedance %f+%fj;\n',RHL,XH);
       fprintf(fid,'     impedance1 %f+%fj;\n',RHT,XL);
       fprintf(fid,'     impedance2 %f+%fj;\n',RLT,XT);
       Z = 7200^2 / (1000 * RawLoadTrans{6}(i) * 0.005);
       R = 7200^2 / (1000 * RawLoadTrans{6}(i) * 0.002);
       fprintf(fid,'     shunt_impedance %.0f+%.0fj;\n',R,Z);
       fprintf(fid,'}\n\n');
    else
       stop = 0;
       for m=1:(i-1)
          if (strcmp(t_conf(1:length(t_conf)),t_confs(m,1:length(t_conf))))
             stop = 1;
             m = i-2;
          end 
       end
 
       if stop ~= 1 
         fprintf(fid,'object transformer_configuration {\n');
         fprintf(fid,'     name "%s";\n',t_conf);
         fprintf(fid,'     connect_type SINGLE_PHASE_CENTER_TAPPED;\n');
         fprintf(fid,'     install_type POLETOP;\n');
         fprintf(fid,'     primary_voltage %5.1f;\n',1000*RawLoadTrans{5}(i));
         fprintf(fid,'     secondary_voltage %3.1f;\n',1000*RawLoadTrans{9}(i));
         fprintf(fid,'     power_rating %2.1f;\n',RawLoadTrans{6}(i));
         fprintf(fid,'     power%s_rating %2.1f;\n',char(RawLoadTrans{4}(i)),RawLoadTrans{10}(i));
         fprintf(fid,'     impedance 0.006+0.0136j;\n');
         fprintf(fid,'     impedance1 0.012+0.0204j;\n');
         fprintf(fid,'     impedance2 0.012+0.0204j;\n');
         Z = 7200^2 / (1000 * RawLoadTrans{6}(i) * 0.005);
         R = 7200^2 / (1000 * RawLoadTrans{6}(i) * 0.002);
         fprintf(fid,'     shunt_impedance %.0f+%.0fj;\n',R,Z);
         fprintf(fid,'}\n\n');          
       end
    end
        
 end
 
% fprintf(fid,'// Center-tap transformers\n\n');
% 
%  for i=1:EndLoadTrans
%      fprintf(fid,'object transformer {\n');
%      fprintf(fid,'     configuration "%.0f%.0f%s";\n',RawLoadTrans{6}(i),RawLoadTrans{10}(i),char(RawLoadTrans{4}(i)));
%      fprintf(fid,'     name "%s";\n',char(RawLoadTrans{1}(i))); 
%      fprintf(fid,'     from "%s";\n',char(RawLoadTrans{3}(i)));   
%      fprintf(fid,'     to "%s";\n',char(RawLoadTrans{7}(i)));
%      fprintf(fid,'     nominal_voltage %s;\n',nom_volt1);
%      fprintf(fid,'     phases %sS;\n',char(RawLoadTrans{4}(i)));
%      fprintf(fid,'}\n\n');    
%  end



%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Create Triplex-Load objects
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
fprintf(fid,'// Triplex Node Objects with loads\n\n');
fprintf(fid,'class player {\n');
fprintf(fid,'      double value;\n');
fprintf(fid,'}\n');

total_houses = 0;
if ( strcmp(houses,'y')~=0 )
    disp('Generating houses...');
    total_houses = 0;
    floor_area_large = 0;
    floor_area_small = 1000000;
    fprintf(fid,'//Step1\n'); 
    % Make sure it's only psuedo-randomized, but repeatable
    s2 = RandStream.create('mrg32k3a','NumStreams',3,'StreamIndices',2);
    RandStream.setGlobalStream(s2);

    for i=1:112
        reload = load_scalar*RawTripLoads{9}(i)*1000;
        imload = load_scalar*RawTripLoads{9}(i)*1000*tan(acos(RawTripLoads{10}(i)));

        no_of_houses = ceil(sqrt(reload^2 + imload^2) / house_scalar / 1000);
        total_houses = total_houses + no_of_houses;
        
        Tph = char(RawTripLoads{3}(i));
        PhLoad = Tph(10);
        
        fprintf(fid,'object node {\n');
        fprintf(fid,'phases ABC;\n');
        fprintf(fid,'name "node_%d";\n',i);
        fprintf(fid,'nominal_voltage 7199.558;\n');
        fprintf(fid,'}\n');
        fprintf(fid,'\n');
     
        fprintf(fid,'object transformer { \n');
        fprintf(fid,'     name transformer_%d; \n',i);
        fprintf(fid,'     phases %sS;\n',PhLoad);
        fprintf(fid,'     from "node_%d";\n',i);
        fprintf(fid,'     to "tnode_%d";\n',i);
        fprintf(fid,'     configuration "7575%s";\n',PhLoad);
        fprintf(fid,'}\n');
        
        fprintf(fid,'object triplex_node {\n');
        fprintf(fid,'     name "tnode_%d";\n',i);
        fprintf(fid,'     nominal_voltage 120;\n');
        fprintf(fid,'     phases %sS;\n\n',PhLoad);
        fprintf(fid,'}\n\n');
        fprintf(fid,'//Step3\n'); 
        fprintf(fid,'     // Converted from load: %.1f+%.1fj\n',reload,imload);
            
     fprintf(fid,'object recorder {\n');
     fprintf(fid,'     name "Recorder%d";\n',i);
     fprintf(fid,'     parent "meter_%d";\n',i);
     fprintf(fid,'     interval 1800;\n');
     fprintf(fid,'     property measured_real_energy,measured_power,measured_real_power,measured_demand,monthly_bill,price;\n');
     fprintf(fid,'     file strom/strom_%d.csv;\n',i);
     fprintf(fid,'}\n');
     
       fprintf(fid,'object triplex_line { \n');
       fprintf(fid,'     name "tline_%d";  \n',i);
       fprintf(fid,'     phases %sS;\n',PhLoad);
       fprintf(fid,'     from "tnode_%d";\n',i);
       fprintf(fid,'     to "meter_%d";\n',i);
       fprintf(fid,'     length 15;\n');
       fprintf(fid,'     configuration "4/0Triplex";\n');
       fprintf(fid,'}\n');
     
      fprintf(fid,'object triplex_meter {  \n');
      fprintf(fid,'     name "meter_%d";\n',i);
      fprintf(fid,'     phases %sS;\n',PhLoad);
      fprintf(fid,'     voltage_1 120; \n');
      fprintf(fid,'     voltage_2 120;\n');
      fprintf(fid,'     voltage_N 0;    \n');
      fprintf(fid,'     nominal_voltage 120;  \n');
      fprintf(fid,'} \n');
      
            fprintf(fid,'//Step5\n'); 
            fprintf(fid,'object house {\n');
            fprintf(fid,'  parent "meter_%d";\n',i);
%             fprintf(fid,'  schedule_skew %.0f;\n',skew);
            fprintf(fid,'  name "house_%d";\n',i);
%             fprintf(fid,'  floor_area %.1f;\n',floor_area);
            
            ti = floor(5*rand(1)) + 3; % can use to shift thermal integrity
            
            if (ti > 6)
                ti = 6;
            end
            
              
            fprintf(fid,'  object ZIPload {\n');
            fprintf(fid,'         name "house%d_load";\n',i);
            fprintf(fid,'         base_power LOAD%d_player.value;\n',i);
            fprintf(fid,'  };\n\n');
            
            fprintf(fid,'  }\n\n');
                
            fprintf(fid,'object player {\n');
            fprintf(fid,'name LOAD%d_player;\n',i);
            fprintf(fid,'file player/Load_profile_%d.player;\n',i);
            fprintf(fid,'}\n\n');
    end 
end



%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Create Triplex-Node objects (non-load objects)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% fprintf(fid,'// Triplex Node Objects without loads\n\n');
% disp('Printing triplex nodes...');
% for i=1:EndTripNodes
%     fprintf(fid,'object triplex_node {\n');
%     fprintf(fid,'     name "%s";\n',char(RawTripLines{2}(i)));
%     fprintf(fid,'     nominal_voltage 120;\n');
%     TphN = char(RawTripLines{4}(i));
%     PhNode = TphN(10);
%     fprintf(fid,'     phases %sS;\n',PhNode);
%     fprintf(fid,'}\n\n');   
% end

%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Create Node objects
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
disp('Printing nodes - this will take some time...');
fprintf(fid,'// Node Objects\n\n');

% Go through 'From' node list, eliminate any repeats
n=0;
for i=1:EndLines
    stop = 0;
    phase = char(RawLines{3}(i));
    phasebit = 0;
    
    if ~isempty(findstr(phase,'A'))
        phasebit = phasebit + 4;
    end
    if ~isempty(findstr(phase,'B'))
        phasebit = phasebit + 2;
    end
    if ~isempty(findstr(phase,'C'))
        phasebit = phasebit + 1;
    end
    
    for m=1:n
        if (strcmp(RawLines{2}(i),Node_Name{1}(m)))
            stop = 1;
            phasebit = bitor(phasebit,Node_Phase{1}(m));
            Node_Phase{1}(m) = phasebit;
            m=n;
        end 
    end
    if stop~=1
        n=n+1;
        Node_Name{1}(n) = RawLines{2}(i);
        Node_Phase{1}(n) = phasebit;
    end
end
% Go through 'to' node list
end_last = n;
for i=(EndLines+1):(EndLines*2)
    stop = 0;
    phase = char(RawLines{3}(i-EndLines));
    phasebit = 0;
    
    if ~isempty(findstr(phase,'A'))
        phasebit = phasebit + 4;
    end
    if ~isempty(findstr(phase,'B'))
        phasebit = phasebit + 2;
    end
    if ~isempty(findstr(phase,'C'))
        phasebit = phasebit + 1;
    end
    
    for m=1:n
        if (strcmp(RawLines{4}(i-EndLines),Node_Name{1}(m)))
            stop = 1;
            phasebit = bitor(phasebit,Node_Phase{1}(m));
            Node_Phase{1}(m) = phasebit;
            m=n;
        elseif (RawLines{6}(i-EndLines)==0.01||RawLines{6}(i-EndLines)==0.001)
            stop = 1;
            m = n;
        end
    end 
    if stop~=1
        n=n+1;
        Node_Name{1}(n) = RawLines{4}(i-EndLines);
        Node_Phase{1}(n) = phasebit;
    end
end
% Print Nodes, but override all of the capacitor nodes to be three phase
for i=1:length(Node_Name{1})
    phasebit = Node_Phase{1}(i);
    
    switch phasebit
        case 1
            phase = 'C';
        case 2
            phase = 'B';
        case 3
            phase = 'BC';
        case 4
            phase = 'A';
        case 5
            phase = 'AC';
        case 6 
            phase = 'AB';
        case 7
            phase = 'ABC';
    end
    
    if (~isempty(findstr(char(Node_Name{1}(i)),'Q'))||(~isempty(findstr(char(Node_Name{1}(i)),'L2823592')))) 
        fprintf(fid,'object node {\n');
        fprintf(fid,'     phases ABCN;\n');
        fprintf(fid,'     name "%s";\n',char(Node_Name{1}(i)));
        fprintf(fid,'     nominal_voltage %s;\n',nom_volt1);
        fprintf(fid,'}\n\n');
    elseif (~isempty(findstr(char(Node_Name{1}(i)),'193-48013'))||(~isempty(findstr(char(Node_Name{1}(i)),'E182745')))||(~isempty(findstr(char(Node_Name{1}(i)),'193-51796')))) 
        % Some weird switch nodes that only need one phase attached
        fprintf(fid,'object node {\n');
        fprintf(fid,'     phases AN;\n');
        fprintf(fid,'     name "%s";\n',char(Node_Name{1}(i)));
        fprintf(fid,'     nominal_voltage %s;\n',nom_volt1);
        fprintf(fid,'}\n\n');
    else
        fprintf(fid,'object node {\n');
        fprintf(fid,'     phases %sN;\n',phase);
        fprintf(fid,'     name "%s";\n',char(Node_Name{1}(i)));
        fprintf(fid,'     nominal_voltage %s;\n',nom_volt1);
        fprintf(fid,'}\n\n');
    end
end

%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Create Line and Conductor Configurations
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
fprintf(fid,'// Overhead Line Conductors and configurations.\n');
disp('Printing lines and conductors...');
%Print the conductors that are needed
 for i = 1:length(CondValues{1})
     if (strcmp(char(CondValues{1}(i)),'397_ACSR')||strcmp(char(CondValues{1}(i)),'2/0_ACSR')||strcmp(char(CondValues{1}(i)),'4_ACSR')||strcmp(char(CondValues{1}(i)),'2_ACSR')||strcmp(char(CondValues{1}(i)),'1/0_ACSR')||strcmp(char(CondValues{1}(i)),'4_WPAL')||strcmp(char(CondValues{1}(i)),'1/0_TPX')||strcmp(char(CondValues{1}(i)),'4/0_TPX')||strcmp(char(CondValues{1}(i)),'4_DPX')||strcmp(char(CondValues{1}(i)),'1/0_3W_CS')||strcmp(char(CondValues{1}(i)),'4_TPX')||strcmp(char(CondValues{1}(i)),'6_WPAL')||strcmp(char(CondValues{1}(i)),'2_WPAL')||strcmp(char(CondValues{1}(i)),'2/0_WPAL')||strcmp(char(CondValues{1}(i)),'DEFAULT')||strcmp(char(CondValues{1}(i)),'600_CU'))
         fprintf(fid,'object overhead_line_conductor {\n');
         fprintf(fid,'     name "%s";\n',char(CondValues{1}(i)));
         fprintf(fid,'     geometric_mean_radius %1.6f%s;\n',CondValues{3}(i),GMRunits);
         fprintf(fid,'     resistance %1.6f%s;\n',CondValues{2}(i),Racunits);
         
             [~,temp_rating] = strtok(CondValues{5}(i),'=');
             [temp_rating,~] = strtok(temp_rating,'=');
             temp_rating = str2double(temp_rating);
         fprintf(fid,'     rating.summer.emergency %.0f A;\n',temp_rating);
         fprintf(fid,'     rating.summer.continuous %.0f A;\n',temp_rating);
         fprintf(fid,'     rating.winter.emergency %.0f A;\n',temp_rating);
         fprintf(fid,'     rating.winter.continuous %.0f A;\n',temp_rating);
         fprintf(fid,'}\n\n');
     end
 end

% Create line spacings 
fprintf(fid,'object line_spacing {\n');
fprintf(fid,'     name SinglePhase1A;\n');
fprintf(fid,'     distance_AN 2.3062m;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_spacing {\n');
fprintf(fid,'     name SinglePhase1B;\n');
fprintf(fid,'     distance_BN 2.3062m;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_spacing {\n');
fprintf(fid,'     name SinglePhase1C;\n');
fprintf(fid,'     distance_CN 2.3062m;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_spacing {\n');
fprintf(fid,'     name TwoPhase1AC;\n');
fprintf(fid,'     distance_AC 1.2192m;\n');
fprintf(fid,'     distance_CN 1.5911m;\n');
fprintf(fid,'     distance_AN 1.70388m;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_spacing {\n');
fprintf(fid,'     name ThreePhase1;\n');
fprintf(fid,'     distance_AB 0.97584m;\n');
fprintf(fid,'     distance_AC 1.2192m;\n');
fprintf(fid,'     distance_BC 0.762m;\n');
fprintf(fid,'     distance_BN 2.1336m;\n');
fprintf(fid,'     distance_AN 1.70388m;\n');
fprintf(fid,'     distance_CN 1.5911m;\n');
fprintf(fid,'}\n\n');

% Create all of the line configurations (67 of them + 3 oddballs)
fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "1PH-x4_ACSRx4_ACSR";\n');
fprintf(fid,'     conductor_B "4_ACSR";\n');
fprintf(fid,'     conductor_N "4_ACSR";\n');
fprintf(fid,'     spacing SinglePhase1B;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "1PH-xx4_ACSR4_ACSR";\n');
fprintf(fid,'     conductor_C "4_ACSR";\n');
fprintf(fid,'     conductor_N "4_ACSR";\n');
fprintf(fid,'     spacing SinglePhase1C;\n');
fprintf(fid,'}\n\n');
                          
fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "1PH-x2_ACSRx2_ACSR";\n');
fprintf(fid,'     conductor_B "2_ACSR";\n');
fprintf(fid,'     conductor_N "2_ACSR";\n');
fprintf(fid,'     spacing SinglePhase1B;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "1PH-x4_ACSRx4_WPAL";\n');
fprintf(fid,'     conductor_B "4_ACSR";\n');
fprintf(fid,'     conductor_N "4_WPAL";\n');
fprintf(fid,'     spacing SinglePhase1B;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "3PH_H-2/0_ACSR2/0_ACSR2/0_ACSR2_ACSR";\n');
fprintf(fid,'     conductor_A "2/0_ACSR";\n');
fprintf(fid,'     conductor_B "2/0_ACSR";\n');
fprintf(fid,'     conductor_C "2/0_ACSR";\n');
fprintf(fid,'     conductor_N "2_ACSR";\n');
fprintf(fid,'     spacing ThreePhase1;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "3PH_H-4_ACSR4_ACSR4_ACSR4_ACSR";\n');
fprintf(fid,'     conductor_A "4_ACSR";\n');
fprintf(fid,'     conductor_B "4_ACSR";\n');
fprintf(fid,'     conductor_C "4_ACSR";\n');
fprintf(fid,'     conductor_N "4_ACSR";\n');
fprintf(fid,'     spacing ThreePhase1;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "1PH-4_WPALxx2_WPAL";\n');
fprintf(fid,'     conductor_A "4_ACSR";\n');
fprintf(fid,'     conductor_N "4_ACSR";\n');
fprintf(fid,'     spacing SinglePhase1A;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "3PH_H-4_ACSR2_ACSR2_ACSR4_WPAL";\n');
fprintf(fid,'     conductor_A "4_ACSR";\n');
fprintf(fid,'     conductor_B "2_ACSR";\n');
fprintf(fid,'     conductor_C "2_ACSR";\n');
fprintf(fid,'     conductor_N "4_WPAL";\n');
fprintf(fid,'     spacing ThreePhase1;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "1PH-4_ACSRxx4_ACSR";\n');
fprintf(fid,'     conductor_A "4_ACSR";\n');
fprintf(fid,'     conductor_N "4_ACSR";\n');
fprintf(fid,'     spacing SinglePhase1A;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "3PH_H-4_ACSR4_ACSR4_ACSR4_WPAL";\n');
fprintf(fid,'     conductor_A "4_ACSR";\n');
fprintf(fid,'     conductor_B "4_ACSR";\n');
fprintf(fid,'     conductor_C "4_ACSR";\n');
fprintf(fid,'     conductor_N "4_WPAL";\n');
fprintf(fid,'     spacing ThreePhase1;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "1PH-2_ACSRxx2_ACSR";\n');
fprintf(fid,'     conductor_A "2_ACSR";\n');
fprintf(fid,'     conductor_N "2_ACSR";\n');
fprintf(fid,'     spacing SinglePhase1A;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "1PH-4_WPALxx4_ACSR";\n');
fprintf(fid,'     conductor_A "4_WPAL";\n');
fprintf(fid,'     conductor_N "4_ACSR";\n');
fprintf(fid,'     spacing SinglePhase1A;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "3PH_H-397_ACSR397_ACSR397_ACSR2/0_ACSR";\n');
fprintf(fid,'     conductor_A "397_ACSR";\n');	
fprintf(fid,'     conductor_B "397_ACSR";\n');
fprintf(fid,'     conductor_C "397_ACSR";\n');
fprintf(fid,'     conductor_N "2/0_ACSR";\n');
fprintf(fid,'     spacing ThreePhase1;\n');
fprintf(fid,'}\n\n');

% Page 2 
fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "1PH-2_ACSRxx4_ACSR";\n');
fprintf(fid,'     conductor_A "2_ACSR";\n');
fprintf(fid,'     conductor_N "4_ACSR";\n');
fprintf(fid,'     spacing SinglePhase1A;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "1PH-xx2_ACSR2_ACSR";\n');
fprintf(fid,'     conductor_C "2_ACSR";\n');
fprintf(fid,'     conductor_N "2_ACSR";\n');
fprintf(fid,'     spacing SinglePhase1C;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "1PH-xx4_WPAL4_WPAL";\n');
fprintf(fid,'     conductor_C "4_WPAL";\n');
fprintf(fid,'     conductor_N "4_WPAL";\n');
fprintf(fid,'     spacing SinglePhase1C;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "1PH-x4_WPALx4_WPAL";\n');
fprintf(fid,'     conductor_B "4_WPAL";\n');
fprintf(fid,'     conductor_N "4_WPAL";\n');
fprintf(fid,'     spacing SinglePhase1B;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "1PH-xx4_WPAL4_ACSR";\n');
fprintf(fid,'     conductor_C "4_WPAL";\n');
fprintf(fid,'     conductor_N "4_ACSR";\n');
fprintf(fid,'     spacing SinglePhase1C;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "1PH-x2_ACSRx1/0_TPX";\n');
fprintf(fid,'     conductor_B "2_ACSR";\n');
fprintf(fid,'     conductor_N "1/0_TPX";\n');
fprintf(fid,'     spacing SinglePhase1B;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "1PH-4_ACSRxx4_WPAL";\n');
fprintf(fid,'     conductor_A "4_ACSR";\n');
fprintf(fid,'     conductor_N "4_WPAL";\n');
fprintf(fid,'     spacing SinglePhase1A;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "1PH-xx4_ACSR1/0_TPX";\n');
fprintf(fid,'     conductor_C "4_ACSR";\n');
fprintf(fid,'     conductor_N "1/0_TPX";\n');
fprintf(fid,'     spacing SinglePhase1C;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "3PH_H-4_WPAL4_WPAL4_WPAL4_ACSR";\n');
fprintf(fid,'     conductor_A "4_WPAL";\n');
fprintf(fid,'     conductor_B "4_WPAL";\n');
fprintf(fid,'     conductor_C "4_WPAL";\n');
fprintf(fid,'     conductor_N "4_ACSR";\n');
fprintf(fid,'     spacing ThreePhase1;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "1PH-x4_WPALx4_ACSR";\n');
fprintf(fid,'     conductor_B "4_WPAL";\n');
fprintf(fid,'     conductor_N "4_ACSR";\n');
fprintf(fid,'     spacing SinglePhase1B;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "1PH-4_WPALxx4_WPAL";\n');
fprintf(fid,'     conductor_A "4_WPAL";\n');
fprintf(fid,'     conductor_N "4_WPAL";\n');
fprintf(fid,'     spacing SinglePhase1A;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "3PH_H-4_WPAL4_WPAL4_WPAL4_WPAL";\n');
fprintf(fid,'     conductor_A "4_WPAL";\n');
fprintf(fid,'     conductor_B "4_WPAL";\n');
fprintf(fid,'     conductor_C "4_WPAL";\n');
fprintf(fid,'     conductor_N "4_WPAL";\n');
fprintf(fid,'     spacing ThreePhase1;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "3PH_H-2_ACSR2_ACSR2_ACSR2_ACSR";\n');
fprintf(fid,'     conductor_A "2_ACSR";\n');
fprintf(fid,'     conductor_B "2_ACSR";\n');
fprintf(fid,'     conductor_C "2_ACSR";\n');
fprintf(fid,'     conductor_N "2_ACSR";\n');
fprintf(fid,'     spacing ThreePhase1;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "1PH-4_ACSRxx1/0_TPX";\n');
fprintf(fid,'     conductor_A "4_ACSR";\n');
fprintf(fid,'     conductor_N "1/0_TPX";\n');
fprintf(fid,'     spacing SinglePhase1A;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "3PH_H-4_ACSR2_ACSR2_ACSR4_ACSR";\n');
fprintf(fid,'     conductor_A "4_ACSR";\n');
fprintf(fid,'     conductor_B "2_ACSR";\n');
fprintf(fid,'     conductor_C "2_ACSR";\n');
fprintf(fid,'     conductor_N "4_ACSR";\n');
fprintf(fid,'     spacing ThreePhase1;\n');
fprintf(fid,'}\n\n');

%Page 3
fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "1PH-xx4_ACSR4_WPAL";\n');
fprintf(fid,'     conductor_C "4_ACSR";\n');
fprintf(fid,'     conductor_N "4_WPAL";\n');
fprintf(fid,'     spacing SinglePhase1C;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "1PH-4_ACSRxx2_ACSR";\n');
fprintf(fid,'     conductor_A "4_ACSR";\n');
fprintf(fid,'     conductor_N "2_ACSR";\n');
fprintf(fid,'     spacing SinglePhase1A;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "1PH-x4_WPALx1/0_TPX";\n');
fprintf(fid,'     conductor_B "4_WPAL";\n');
fprintf(fid,'     conductor_N "1/0_TPX";\n');
fprintf(fid,'     spacing SinglePhase1B;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "1PH-xx4_ACSR1/0_ACSR";\n');
fprintf(fid,'     conductor_C "4_ACSR";\n');
fprintf(fid,'     conductor_N "1/0_ACSR";\n');
fprintf(fid,'     spacing SinglePhase1C;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "1PH-2_ACSRxx4_WPAL";\n');
fprintf(fid,'     conductor_A "2_ACSR";\n');
fprintf(fid,'     conductor_N "4_WPAL";\n');
fprintf(fid,'     spacing SinglePhase1A;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "1PH-xx2/0_ACSR1/0_TPX";\n');
fprintf(fid,'     conductor_C "2/0_ACSR";\n');
fprintf(fid,'     conductor_N "1/0_TPX";\n');
fprintf(fid,'     spacing SinglePhase1C;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "2PH_H-2_ACSRx2_ACSR2_ACSR";\n');
fprintf(fid,'     conductor_A "2_ACSR";\n');
fprintf(fid,'     conductor_C "2_ACSR";\n');
fprintf(fid,'     conductor_N "2_ACSR";\n');
fprintf(fid,'     spacing TwoPhase1AC;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "1PH-2_WPALxx2_WPAL";\n');
fprintf(fid,'     conductor_A "2_WPAL";\n');
fprintf(fid,'     conductor_N "2_WPAL";\n');
fprintf(fid,'     spacing SinglePhase1A;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "1PH-2_ACSRxx4/0_TPX";\n');
fprintf(fid,'     conductor_A "2_ACSR";\n');
fprintf(fid,'     conductor_N "4/0_TPX";\n');
fprintf(fid,'     spacing SinglePhase1A;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "3PH_H-397_ACSR397_ACSR397_ACSR4_WPAL";\n');
fprintf(fid,'     conductor_A "397_ACSR";\n');
fprintf(fid,'     conductor_B "397_ACSR";\n');
fprintf(fid,'     conductor_C "397_ACSR";\n');
fprintf(fid,'     conductor_N "4_WPAL";\n');
fprintf(fid,'     spacing ThreePhase1;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "3PH_H-397_ACSR397_ACSR397_ACSR397_ACSR";\n');
fprintf(fid,'     conductor_A "397_ACSR";\n');
fprintf(fid,'     conductor_B "397_ACSR";\n');
fprintf(fid,'     conductor_C "397_ACSR";\n');
fprintf(fid,'     conductor_N "397_ACSR";\n');
fprintf(fid,'     spacing ThreePhase1;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "1PH-xx2_ACSR1/0_TPX";\n');
fprintf(fid,'     conductor_C "2_ACSR";\n');
fprintf(fid,'     conductor_N "1/0_TPX";\n');
fprintf(fid,'     spacing SinglePhase1C;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "1PH-x4_ACSRx2_WPAL";\n');
fprintf(fid,'     conductor_B "4_ACSR";\n');
fprintf(fid,'     conductor_N "2_WPAL";\n');
fprintf(fid,'     spacing SinglePhase1B;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "1PH-x4_ACSRx4_DPX";\n');
fprintf(fid,'     conductor_B "4_ACSR";\n');
fprintf(fid,'     conductor_N "4_DPX";\n');
fprintf(fid,'     spacing SinglePhase1B;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "3PH_H-2_ACSR2_ACSR4_ACSR4_ACSR";\n');
fprintf(fid,'     conductor_A "2_ACSR";\n');
fprintf(fid,'     conductor_B "2_ACSR";\n');
fprintf(fid,'     conductor_C "4_ACSR";\n');
fprintf(fid,'     conductor_N "4_ACSR";\n');
fprintf(fid,'     spacing ThreePhase1;\n');
fprintf(fid,'}\n\n');

% Page 4
fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "1PH-4_WPALxx1/0_TPX";\n');
fprintf(fid,'     conductor_A "4_WPAL";\n');
fprintf(fid,'     conductor_N "1/0_TPX";\n');
fprintf(fid,'     spacing SinglePhase1A;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "1PH-x4_ACSRx1/0_TPX";\n');
fprintf(fid,'     conductor_B "4_ACSR";\n');
fprintf(fid,'     conductor_N "1/0_TPX";\n');
fprintf(fid,'     spacing SinglePhase1B;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "1PH-4_ACSRxx1/0_3W_CS";\n');
fprintf(fid,'     conductor_A "4_ACSR";\n');
fprintf(fid,'     conductor_N "1/0_3W_CS";\n');
fprintf(fid,'     spacing SinglePhase1A;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "1PH-x2_ACSRx4_ACSR";\n');
fprintf(fid,'     conductor_B "2_ACSR";\n');
fprintf(fid,'     conductor_N "4_ACSR";\n');
fprintf(fid,'     spacing SinglePhase1B;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "1PH-x2_ACSRx1/0_3W_CS";\n');
fprintf(fid,'     conductor_B "2_ACSR";\n');
fprintf(fid,'     conductor_N "1/0_3W_CS";\n');
fprintf(fid,'     spacing SinglePhase1B;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "3PH_H-2/0_ACSR2/0_ACSR2/0_ACSR2/0_ACSR";\n');
fprintf(fid,'     conductor_A "2/0_ACSR";\n');
fprintf(fid,'     conductor_B "2/0_ACSR";\n');
fprintf(fid,'     conductor_C "2/0_ACSR";\n');
fprintf(fid,'     conductor_N "2/0_ACSR";\n');
fprintf(fid,'     spacing ThreePhase1;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "1PH-2_ACSRxx1/0_TPX";\n');
fprintf(fid,'     conductor_A "2_ACSR";\n');
fprintf(fid,'     conductor_N "1/0_TPX";\n');
fprintf(fid,'     spacing SinglePhase1A;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "3PH_H-4_WPAL4_WPAL4_WPAL1/0_TPX";\n');
fprintf(fid,'     conductor_A "4_WPAL";\n');
fprintf(fid,'     conductor_B "4_WPAL";\n');
fprintf(fid,'     conductor_C "4_WPAL";\n');
fprintf(fid,'     conductor_N "1/0_TPX";\n');
fprintf(fid,'     spacing ThreePhase1;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "1PH-x4_WPALx2_ACSR";\n');
fprintf(fid,'     conductor_B "4_WPAL";\n');
fprintf(fid,'     conductor_N "2_ACSR";\n');
fprintf(fid,'     spacing SinglePhase1B;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "3PH_H-2/0_ACSR2/0_ACSR2/0_ACSR2_WPAL";\n');
fprintf(fid,'     conductor_A "2/0_ACSR";\n');
fprintf(fid,'     conductor_B "2/0_ACSR";\n');
fprintf(fid,'     conductor_C "2/0_ACSR";\n');
fprintf(fid,'     conductor_N "2_WPAL";\n');
fprintf(fid,'     spacing ThreePhase1;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "1PH-xx4_ACSR2_ACSR";\n');
fprintf(fid,'     conductor_C "4_ACSR";\n');
fprintf(fid,'     conductor_N "2_ACSR";\n');
fprintf(fid,'     spacing SinglePhase1C;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "1PH-x4_ACSRx4_TPX";\n');
fprintf(fid,'     conductor_B "4_ACSR";\n');
fprintf(fid,'     conductor_N "4_TPX";\n');
fprintf(fid,'     spacing SinglePhase1B;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "3PH_H-4_ACSR4_ACSR4_ACSR4_TPX";\n');
fprintf(fid,'     conductor_A "4_ACSR";\n');
fprintf(fid,'     conductor_B "4_ACSR";\n');
fprintf(fid,'     conductor_C "4_ACSR";\n');
fprintf(fid,'     conductor_N "4_TPX";\n');
fprintf(fid,'     spacing ThreePhase1;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "1PH-4_ACSRxx6_WPAL";\n');
fprintf(fid,'     conductor_A "4_ACSR";\n');
fprintf(fid,'     conductor_N "6_WPAL";\n');
fprintf(fid,'     spacing SinglePhase1A;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "1PH-xx4_ACSR4_TPX";\n');
fprintf(fid,'     conductor_C "4_ACSR";\n');
fprintf(fid,'     conductor_N "4_TPX";\n');
fprintf(fid,'     spacing SinglePhase1C;\n');
fprintf(fid,'}\n\n');

% Page 5
fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "3PH_H-397_ACSR397_ACSR397_ACSR2/0_WPAL";\n');
fprintf(fid,'     conductor_A "397_ACSR";\n');
fprintf(fid,'     conductor_B "397_ACSR";\n');
fprintf(fid,'     conductor_C "397_ACSR";\n');
fprintf(fid,'     conductor_N "2/0_WPAL";\n');
fprintf(fid,'     spacing ThreePhase1;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "1PH-2/0_ACSRxx2_ACSR";\n');
fprintf(fid,'     conductor_A "2/0_ACSR";\n');
fprintf(fid,'     conductor_N "2_ACSR";\n');
fprintf(fid,'     spacing SinglePhase1A;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "3PH_H-2/0_ACSR2/0_ACSR2/0_ACSR4_ACSR";\n');
fprintf(fid,'     conductor_A "2/0_ACSR";\n');
fprintf(fid,'     conductor_B "2/0_ACSR";\n');
fprintf(fid,'     conductor_C "2/0_ACSR";\n');
fprintf(fid,'     conductor_N "4_ACSR";\n');
fprintf(fid,'     spacing ThreePhase1;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "1PH-xx4_WPAL1/0_TPX";\n');
fprintf(fid,'     conductor_C "4_WPAL";\n');
fprintf(fid,'     conductor_N "1/0_TPX";\n');
fprintf(fid,'     spacing SinglePhase1C;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "1PH-xx6_WPAL6_WPAL";\n');
fprintf(fid,'     conductor_C "6_WPAL";\n');
fprintf(fid,'     conductor_N "6_WPAL";\n');
fprintf(fid,'     spacing SinglePhase1C;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "1PH-x2_ACSRx4_TPX";\n');
fprintf(fid,'     conductor_B "2_ACSR";\n');
fprintf(fid,'     conductor_N "4_TPX";\n');
fprintf(fid,'     spacing SinglePhase1B;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "3PH_H-4_ACSR4_ACSR4_ACSR2_WPAL";\n');
fprintf(fid,'     conductor_A "4_ACSR";\n');
fprintf(fid,'     conductor_B "4_ACSR";\n');
fprintf(fid,'     conductor_C "4_ACSR";\n');
fprintf(fid,'     conductor_N "2_WPAL";\n');
fprintf(fid,'     spacing ThreePhase1;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "1PH-x4_ACSRx1/0_3W_CS";\n');
fprintf(fid,'     conductor_B "4_ACSR";\n');
fprintf(fid,'     conductor_N "1/0_3W_CS";\n');
fprintf(fid,'     spacing SinglePhase1B;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "1PH-xx2_ACSR4_DPX";\n');
fprintf(fid,'     conductor_C "2_ACSR";\n');
fprintf(fid,'     conductor_N "4_DPX";\n');
fprintf(fid,'     spacing SinglePhase1B;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "3P_1/0_AXNJ_DB";\n');
fprintf(fid,'     conductor_A "1/0_ACSR"; //These are not the correct values,\n'); 
fprintf(fid,'     conductor_B "1/0_ACSR"; //but are used to approximate for 3P & 1P.\n'); 
fprintf(fid,'     conductor_C "1/0_ACSR";\n'); 
fprintf(fid,'     conductor_N "1/0_ACSR";\n');
fprintf(fid,'     spacing ThreePhase1;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "1P_1/0_AXNJ_DB_A";\n');
fprintf(fid,'     conductor_A "1/0_ACSR";\n');
fprintf(fid,'     conductor_N "1/0_ACSR";\n');
fprintf(fid,'     spacing SinglePhase1A;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "1P_1/0_AXNJ_DB_B";\n');
fprintf(fid,'     conductor_B "1/0_ACSR";\n');
fprintf(fid,'     conductor_N "1/0_ACSR";\n');
fprintf(fid,'     spacing SinglePhase1B;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "1P_1/0_AXNJ_DB_C";\n');
fprintf(fid,'     conductor_C "1/0_ACSR";\n');
fprintf(fid,'     conductor_N "1/0_ACSR";\n');
fprintf(fid,'     spacing SinglePhase1C;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "CAP_LINE";      //Also known as 1PH-Connector.\n');
fprintf(fid,'     conductor_A "600_CU"; //These are not the correct values, but\n');
fprintf(fid,'     conductor_B "600_CU"; //will be used to approx. low loss lines.\n');
fprintf(fid,'     conductor_C "600_CU";\n');
fprintf(fid,'     conductor_N "600_CU";\n');
fprintf(fid,'     spacing ThreePhase1;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "3PH-Connector";\n');
fprintf(fid,'     conductor_A "600_CU";\n');
fprintf(fid,'     conductor_B "600_CU";\n');
fprintf(fid,'     conductor_C "600_CU";\n');
fprintf(fid,'     conductor_N "600_CU";\n');
fprintf(fid,'     spacing ThreePhase1;\n');
fprintf(fid,'}\n\n');

%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Create Triplex Line and Conductor Configurations
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

fprintf(fid,'object triplex_line_conductor {\n');
fprintf(fid,'     name "4/0triplex";\n');
fprintf(fid,'     resistance 1.535;\n');
fprintf(fid,'     geometric_mean_radius 0.0111;\n');
fprintf(fid,'     rating.summer.emergency 315 A;\n');
fprintf(fid,'     rating.summer.continuous 315 A;\n');
fprintf(fid,'     rating.winter.emergency 315 A;\n');
fprintf(fid,'     rating.winter.continuous 315 A;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object triplex_line_configuration {\n');
fprintf(fid,'     name "4/0Triplex";\n');
fprintf(fid,'     conductor_1 "4/0triplex";\n'); 
fprintf(fid,'     conductor_2 "4/0triplex";\n');
fprintf(fid,'     conductor_N "4/0triplex";\n');
fprintf(fid,'     insulation_thickness 0.08;\n');
fprintf(fid,'     diameter 0.368;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object triplex_line_configuration {\n');
fprintf(fid,'     name "750_Triplex";       //These values are not correct, but\n');
fprintf(fid,'     conductor_1 "4/0triplex"; //there are only four of them.\n');
fprintf(fid,'     conductor_2 "4/0triplex";\n');
fprintf(fid,'     conductor_N "4/0triplex";\n');
fprintf(fid,'     insulation_thickness 0.08;\n');
fprintf(fid,'     diameter 0.368;\n');
fprintf(fid,'}\n\n');


%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Create line objects
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

fprintf(fid,'// Overhead Lines\n\n');

for i=1:EndLines
    if (~isempty(findstr(char(RawLines{1}(i)),'CAP')))
        % if it's a capacitor line don't create a line - 
        %  create capacitor lines by hand to combine the three phasees
    elseif (~isempty(findstr(char(RawLines{1}(i)),'_sw')))
        %switches
        if (~isempty(findstr(char(RawLines{1}(i)),'WF586_48332_sw')) || ~isempty(findstr(char(RawLines{1}(i)),'V7995_48332_sw')) || ~isempty(findstr(char(RawLines{1}(i)),'WD701_48332_sw')))
            % do nothing - these are open switches connecting two different
            % phases - doesn't work in NR right now
        else
            fprintf(fid,'object switch {\n');
            fprintf(fid,'     phases %sN;\n',char(RawLines{3}(i)));
            fprintf(fid,'     name "%s";\n',char(RawLines{1}(i)));
            fprintf(fid,'     from "%s";\n',char(RawLines{2}(i)));
            fprintf(fid,'     to "%s";\n',char(RawLines{4}(i)));
            status = strtrim(char(RawLines{9}(i)));
            if (~isempty(findstr(status,'open')))
                fprintf(fid,'     status OPEN;\n');
            else
                fprintf(fid,'     status CLOSED;\n');
            end
            fprintf(fid,'}\n\n');
        end
    elseif (~isempty(findstr(char(RawLines{8}(i)),'1P_1/0_AXNJ_DB')))
        fprintf(fid,'object overhead_line {\n');
        fprintf(fid,'     phases %sN;\n',char(RawLines{3}(i))); 
        fprintf(fid,'     name "%s";\n',char(RawLines{1}(i)));
        fprintf(fid,'     from "%s";\n',char(RawLines{2}(i)));
        fprintf(fid,'     to "%s";\n',char(RawLines{4}(i)));
        fprintf(fid,'     length %f%s;\n',LengthLines(i),char(RawLines{7}(i)));
        k = strtrim(char(RawLines{8}(i)));
        fprintf(fid,'     configuration "%s_%s";\n',k,char(RawLines{3}(i)));
        fprintf(fid,'}\n\n');
    else
        % normal lines
        fprintf(fid,'object overhead_line {\n');
        fprintf(fid,'     phases %sN;\n',char(RawLines{3}(i)));
        % one odd ball line had a node name, so add LN to it
        if (strcmp(char(RawLines{1}(i)),'293471'))
            fprintf(fid,'     name "LN%s";\n',char(RawLines{1}(i)));
        else
            fprintf(fid,'     name "%s";\n',char(RawLines{1}(i)));
        end
        fprintf(fid,'     from "%s";\n',char(RawLines{2}(i)));
        fprintf(fid,'     to "%s";\n',char(RawLines{4}(i)));
        fprintf(fid,'     length %f%s;\n',LengthLines(i),char(RawLines{7}(i)));
          k = strtrim(char(RawLines{8}(i)));
        fprintf(fid,'     configuration "%s";\n',k);
        fprintf(fid,'}\n\n');
        
    end
end
% fprintf(fid,'object overhead_line {\n');
% fprintf(fid,'     phases ABCN;\n'); 
% fprintf(fid,'     name CAP_1;\n');
% fprintf(fid,'     from Q16642;\n');
% fprintf(fid,'     to Q16642_CAP;\n');
% fprintf(fid,'     length 0.01km;\n');
% fprintf(fid,'     configuration "CAP_LINE";\n');
% fprintf(fid,'}\n\n');
% 
% fprintf(fid,'object overhead_line {\n');
% fprintf(fid,'     phases ABCN;\n'); 
% fprintf(fid,'     name CAP_2;\n');
% fprintf(fid,'     from Q16483;\n');
% fprintf(fid,'     to Q16483_CAP;\n');
% fprintf(fid,'     length 0.001km;\n');
% fprintf(fid,'     configuration "CAP_LINE";\n');
% fprintf(fid,'}\n\n');
% 
% fprintf(fid,'object overhead_line {\n');
% fprintf(fid,'     phases ABCN;\n'); 
% fprintf(fid,'     name CAP_3;\n');
% fprintf(fid,'     from L2823592;\n');
% fprintf(fid,'     to L2823592_CAP;\n');
% fprintf(fid,'     length 0.01km;\n');
% fprintf(fid,'     configuration "CAP_LINE";\n');
% fprintf(fid,'}\n\n');

%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Create Triplex-Line objects
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% fprintf(fid,'// Triplex Lines\n\n');
% disp('Printing triplex lines...');
% for i=1:EndTripLines
%     fprintf(fid,'object triplex_line {\n');
%     fprintf(fid,'     name "%s";\n',char(RawTripLines{1}(i)));
%     Tp = char(RawTripLines{4}(i));
%     Tphase = Tp(10);
%     fprintf(fid,'     phases %sS;\n',Tphase);
%     fprintf(fid,'     from "%s";\n',char(RawTripLines{2}(i)));
%     fprintf(fid,'     to "%s";\n',char(RawTripLines{4}(i)));
%     if (strcmp(houses,'y')~= 0)
%         fprintf(fid,'     length %.1fft;\n',25-20*rand(1));
%     else
%         fprintf(fid,'     length %2.0fft;\n',RawTripLines{7}(i));
%     end
%     fprintf(fid,'     configuration "%s";\n',char(RawTripLines{6}(i)));
%     fprintf(fid,'}\n\n');
% end

if ( strcmp(houses,'y')~=0 )
    fprintf(fid,'// Floor area: smallest: %.1f, largest: %.1f\n',floor_area_small,floor_area_large);
    fprintf(fid,'// Total number of houses: %d',total_houses);
    fprintf(fid,'// Load Scalar: %f',load_scalar);
    fprintf(fid,'// House Scalar: %f',house_scalar);
    fprintf(fid,'// ZIP Scalar: %f',zip_scalar);
end

fclose('all');
disp('File generation completed.');
