filepath = "~/Documents/Old_Computers/6809/Flex/DSK";
%filename = "SYSMAIN.DSK";
%filename = "FLEX4SYS.DSK";
%filename = "FLEX.DSK";
filename = "FLEX09.DSK";
%filename = "DISK32.DSK";
%filename = "6809BOOT.DSK";
%filename = "SWFLEX9.DSK";
%filename = "FLEX9SYS.DSK";
%filename = "NEWFLEX.DSK";

[fpath,name,ext] = fileparts(filename);
fullname = [filepath, "/", filename];
fileID = fopen(fullname, "rt+");
Disk = fread(fileID);
fclose(fileID);

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


% The directory starts at track 0, sector 5. The first two bytes point to
% the next directory sector, and the last 240 bytes contain 10 directory
% entries.
DirSector = [];
FileName = "";
FileExtension = "";
StartTrack = "";
StartSector = "";
EndTrack = "";
EndSector = "";
TotalSectors = "";
Month = "";
Day = "";
Year = "";

NextTrack = 0;
NextSector = 5;

while ~((NextTrack == 0) && (NextSector == 0))
   DirSector = DiskImage(NextTrack+1, NextSector, :);
   % The first two entries point to the next sector of the directory, until
   % the last one, which points to track = 0, sector = 0.
   NextTrack = DirSector(1);
   NextSector = DirSector(2);

   % Now remove the first 16 entries to get the directory entries.
   % The sector now contains 10 file entries that can be converted to an array.

   SectorBuffer = DirSector(:, 17:256);
   SectorBuffer = transpose(reshape(SectorBuffer, 24, 10));
   FileName = vertcat(FileName, char(SectorBuffer(:, 1:8)));
   FileExtension = vertcat(FileExtension, char(SectorBuffer(:, 9:11)));
   StartTrack = vertcat(StartTrack, char(SectorBuffer(:, 14)));
   StartSector = vertcat(StartSector, char(SectorBuffer(:, 15)));
   EndTrack = vertcat(EndTrack, char(SectorBuffer(:, 16)));
   EndSector = vertcat(EndSector, char(SectorBuffer(:, 17)));
   TotalSectors = vertcat(TotalSectors, char((SectorBuffer(:, 18).*256)+SectorBuffer(:, 19)));
   Month = vertcat(Month, char(SectorBuffer(:, 22)));
   Day = vertcat(Day, char(SectorBuffer(:, 23)));
   Year = vertcat(Year, char(SectorBuffer(:, 24)));

end

% Print the directory details
fprintf("                 Start         End \n");
fprintf("Filename Ext. Track Sector Track Sector Tot. Sectors Date\n");
fprintf("-----------------------------------------------------------------------------\n");
for Loop = 1:1:size(FileName, 1)
    if (TotalSectors(Loop) ~= 0)
       LineOut = "";
       LineOut = strjust(FileName(Loop, :), "Left");
       LineOut = cstrcat(LineOut, " ", strjust(FileExtension(Loop, :), "Left"));
       printf("%s", LineOut);
       printf(" %3i  ", StartTrack(Loop, :));
       printf(" %3i   ", StartSector(Loop, :));
       printf(" %3i  ", EndTrack(Loop, :));
       printf(" %3i   ", EndSector(Loop, :));
       printf(" %5i       ", TotalSectors(Loop, :));
       printf(" %02i/%02i/%02i \n", Day(Loop, :), Month(Loop, :), Year(Loop, :));
    end
end

