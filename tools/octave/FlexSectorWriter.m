close all
clear
clc
filepath = "~/Documents/Old_Computers/6809/Flex/DSK/Flex91";
filename = "AB094.DSK";

pkg load instrument-control
supportedinterfaces = instrhwinfo().SupportedInterfaces;

if ! isempty(strfind (supportedinterfaces , "serial"))
    disp("Serial: Supported")
else
    disp("Serial: Unsupported")
endif


[fpath,name,ext] = fileparts(filename);
fullname = [filepath, "/", filename];
fprintf("Reading Disk\n");
fileID = fopen(fullname, "rt+");
Disk = fread(fileID);
fclose(fileID);

StartTime = ctime (time ());
% The whole disk is read as a single column vector. This can be reshaped
% as a set of sectors, each column is a sector.
TotalNumberOfSectors = size(Disk, 1)/256;
SectorList = reshape(Disk, 256, TotalNumberOfSectors);

% Isolating the third sector of the first track produces the SIR. This
% contains the number of tracks, and sectors/track.
SIR = SectorList(:, 3);

% This is the layout of the SIR:
% The first 16 bytes are not used (all zeros)
% offset(hex)   size(hex)   contents
% -----------   ---------   -------------------------
%    $10           $0B       Volume Label
%    $1B           $01       Volume Number High byte
%    $1C           $01       Volume Number Low byte
%    $1D           $01       First User Track
%    $1E           $01       First User Sector
%    $1F           $01       Last User Track
%    $20           $01       Last User Sector
%    $21           $01       Total Sectors High byte
%    $22           $01       Total Sectors Low byte
%    $23           $01       Creation Month
%    $24           $01       Creation Day
%    $25           $01       Creation Year
%    $26           $01       Max Track
%    $27           $01       Max Sector

NumberOfTracks = SIR(39)+1;
NumberOfSectors = SIR(40);
fprintf("Disk geometry: %i Tracks, %i Sectors\n\n", NumberOfTracks, NumberOfSectors);

% Re-create the disk structure
DiskImage = [];
for Track = 1:1:NumberOfTracks
    for Sector = 1:1:NumberOfSectors
        Index = ((Track-1)*NumberOfSectors)+Sector;
        DiskImage(Track, Sector, :) = SectorList(:, Index);
    end
end
fprintf("Disk ready for downloading\n");

% DiskImage is a replica of the disk, and can be sent to the SBC one sector at a time to transfer it to real hardware.





% Configure a serial connection to the computer
s1 = serialport ("/dev/cu.usbserial-A50285BI", "baudrate", 38400, "DataBits", 8, "parity", "N", "stopbits", 1)
%s1 = serialport ("/dev/cu.usbserial-4", "baudrate", 38400, "DataBits", 8, "parity", "N", "stopbits", 1)
%configureTerminator (s1, "cr/lf");
configureTerminator (s1, "cr");
setDTR (s1, true)  # Enables DTR line
setRTS (s1, true)  # Enables RTS line
flush (s1);

% From the monitor prompt, jump to the CF Card utility on the SBC.
numbytes = fprintf (s1, "G 8000\n"); 
pause (1);   
%printf ( "%s", char (fread (s1)));
pause (0.1);   
numbytes = fprintf (s1, "\n");                                  
numbytes = fprintf (s1, "\n");                                  
numbytes = fprintf (s1, "\n");                                  
pause (0.1);   
printf ( "%s", char (fread (s1)));

% Start by initialising the CF card & printing CF Card data.
numbytes = fprintf (s1, "I\n"); 
pause (1);   
printf ( "%s", char (fread (s1)));
pause (0.1);   
numbytes = fprintf (s1, "\n");                                  
numbytes = fprintf (s1, "\n");                                  
numbytes = fprintf (s1, "\n");                                  
printf ( "%s", char (fread (s1)));

pause (1);   



numbytes = fprintf (s1, "P\n"); 
pause (1);   
printf ( "%s", char (fread (s1)));
% And now write each sector to the CF Card.
for Track =1:NumberOfTracks
   % Set the track number
   numbytes = fprintf (s1, "T\n");                                  
   pause (0.2);                                 
   printf ( "%s", char (fread (s1)));
   printf ( "%s", char (fread (s1)));
   
   numbytes = fprintf (s1, "%s", dec2hex(Track-1, 2));                                  
   pause (0.2);                                 
   numbytes = fprintf (s1, "\n");                                  
   numbytes = fprintf (s1, "\n");                                  
   numbytes = fprintf (s1, "\n");                                  
   pause (0.2);                                 
   printf ( "%s", char (fread (s1)));
   pause (1);                                 
   
   for Sector = 1:NumberOfSectors
      numbytes = fprintf (s1, "S\n");                                  
      pause (0.2);                                 
      printf ( "%s", char (fread (s1)));
      printf ( "%s", char (fread (s1)));
      
      numbytes = fprintf (s1, "%s\n", dec2hex(Sector, 2));                                  
      pause (0.2);                                 
      numbytes = fprintf (s1, "\n");                                  
      numbytes = fprintf (s1, "\n");                                  
      pause (0.2);                                 
      printf ( "%s", char (fread (s1)));
      pause (1);                                 
      
      numbytes = fprintf (s1, "B\n");                                  
      pause (0.2);                                 
      printf ( "%s", char (fread (s1)));
      printf ( "%s", char (fread (s1)));
      for Byte = 1:256
         numbytes = fprintf (s1, "%s", dec2hex(DiskImage(Track, Sector, Byte), 2));
         pause (0.1);                                 
         printf ( "%s", char (fread (s1)));
      endfor
      pause (0.2);                                 
      printf ( "%s", char (fread (s1)));
      numbytes = fprintf (s1, "W\n");                                  
      pause (0.2);                                 
      printf ( "%s", char (fread (s1)));
      pause (0.2);                                 
      printf ( "%s", char (fread (s1)));
   endfor
endfor
EndTime = ctime (time ());
printf ( "%s\n", StartTime);
printf ( "%s\n", EndTime);
%clear s1




