function [Korrespondenzen_robust , largest_set_size] = F_ransac(Korrespondenzen, varargin)
    % F_ransac F�hre RANSAC-Algorithmus aus.
    %   [Korrespondenzen_robust] = F_ransac(Korrespondenzen, 'epsilon', 0.5, 'p', 0.9, 'tolerance', 0.1);
    %   Diese Funktion f�hrt den RANSAC-Algorithmus zur Bestimmung von
    %   robusten Korrespondenzpunktpaaren aus. Als Eingabeparameter erh�lt
    %   die Funktion eine Matrix, welche die Korrespondenzpunkte erh�lt
    %   (die ersten beiden Eintr�ge einer Spalte entsprechen den x- und
    %   y-Koordinaten des Punktes in Kameraframe 1 und die letzten beiden
    %   Eintr�ge einer Spalte entsprechen den x- und y-Koordinaten 
    %   des Punktes in Kameraframe 2). Zus�tzlich k�nnen �ber einen Input
    %   Parser Werte f�r epsilon (Anteil der Ausrei�er), p (gew�nschte
    %   Wahrscheinlichkeit, dass kein Ausrei�er enthalten ist) und 
    %   tolerance (Toleranz) vorgegeben werden. Der Parameter epsilon, aus
    %   dem sich die Zahl der Iterationen berechnet, wird adaptiv angepasst.
    %   Als R�ckgabeparameter �bergibt die Funktion einen Satz robuster
    %   Korrespondenzpunktpaare.
    %
    % Erstellt: Juli 2019
    
    global gui_waitbar_handle;
    global gui_waitbar_text_handle;
    global gui_waitbar_perc_handle;
    
    %% Nachricht anzeigen (1/2).
    disp('   Der RANSAC-Algorithmus wurde gestartet.');
    
    %% Waitbar erzeugen
    if isempty(gui_waitbar_handle)
        dis_waitbar = waitbar(0, 'Performing RANSAC Algorithm, Progress:');
        set(gui_waitbar_handle, 'XData', [0 0 0 0]);
        set(gui_waitbar_perc_handle, 'String', '0.0 %');
        drawnow;
    else
        set(gui_waitbar_text_handle, 'String', 'Performing RANSAC Algorithm:');
    end
    
    %% Input parser
    parser = inputParser;
    
    % Standartwerte
    % Anteil der Ausrei�er.
    default_epsilon = 0.5; 
    % Gew�nschte Wahrscheinlichkeit, dass kein Ausrei�er im Consensus Set
    % enthalten ist.
    default_p = 0.999;
    % Toleranzbereich.
    default_tolerance = 0.01;
    
    % Pr�ffunktionen
    check_epsilon = @(x) isnumeric(x) && (0 <= x) && (x <= 1);
    check_p = @(x) isnumeric(x) && (0 <= x) && (x <= 1);
    check_tolerance = @(x) isnumeric(x);
    
    % Parameter hinzuf�gen
    addOptional(parser, 'epsilon', default_epsilon, check_epsilon);
    addOptional(parser, 'p', default_p, check_p);
    addOptional(parser,'tolerance',default_tolerance,check_tolerance);
    
    % Parse Inputs
    parse(parser,varargin{:});
    
    epsilon = parser.Results.epsilon;
    p = parser.Results.p;
    tolerance = parser.Results.tolerance;
    
    %% Homogene Koordinaten
    x1_pixel = Korrespondenzen(1:2,:);
    x1_pixel(3,:)=1;
    x2_pixel = Korrespondenzen(3:4,:);
    x2_pixel(3,:)=1;
    
    %% RANSAC Algorithmus Vorbereitung
    k = 8;
    num_iterations = log(1-p)/log(1-(1-epsilon)^k);
    largest_set_size = 0;
    largest_set_dist = inf;
    largest_set_F = zeros(3);
    
    %% RANSAC Algorithmus 
    i = 1;
    while (i <= num_iterations)
        random_rows = randperm(size(Korrespondenzen,2),k);
        F = achtpunktalgorithmus(Korrespondenzen(:,random_rows));
        sd = sampson_dist(F, x1_pixel, x2_pixel);
        set_size = sum(sd<tolerance);
        set_dist = sum(sd);
        if (set_size > largest_set_size)||((set_size == largest_set_size) && (set_dist < largest_set_dist))
            largest_set_size = set_size;
            largest_set_dist = set_dist;
            largest_set_F = F;
            Korrespondenzen_robust = Korrespondenzen(:,(sd<tolerance));
            if (1-(largest_set_size/size(Korrespondenzen,2)))<epsilon
                epsilon = (1-(largest_set_size/size(Korrespondenzen,2)));
                num_iterations = log(1-p)/log(1-(1-epsilon)^k);
            end
        end
        i = i+1;
        
        % Waitbar updaten.
        progress = i/num_iterations;
        if ~isempty(gui_waitbar_handle)
            set(gui_waitbar_handle, 'XData', [0 0 progress progress]);
            set(gui_waitbar_perc_handle, 'String', [num2str(progress*100,'%.1f') ' %']);
            drawnow;
        else
            waitbar(progress, dis_waitbar);
        end
    end 
    
    if isempty(gui_waitbar_handle)
        close(dis_waitbar);
    end
    %% Nachricht anzeigen (1/2).
    fprintf('   Der RANSAC-Algorithmus ist durchglaufen.\n   Anzahl der robusten Korrespondenzpunktpaare: %i \n', largest_set_size);
    
end