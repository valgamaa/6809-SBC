close all
clear
clc
filepath = "~/Documents/Old_Computers/6809/Flex/DSK";
%filename = "6809BOOT.DSK";
%filename = "FLEX.DSK";
%filename = "FLEX09.DSK";
%filename = "TSCFLX09.DSK";
filename = "AB094.DSK";
%DiskFileName = "BASIC.CMD";
DiskFileName = "FLEX.COR";
%DiskFileName = "FLEX981.SYS";
OutputFilePath = "~/Documents/Old_Computers/6809/Flex/DSK";
OutputFileName = "FLEX";

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

% Extract the first sector of the file, if it exists
for Loop = 1:1:size(FileName, 1)
    if (TotalSectors(Loop) ~= 0)
       Text = deblank(FileName(Loop, :));
       if strcmp(DiskFileName, strcat(deblank(FileName(Loop, :)), ".", FileExtension(Loop, :))) == 1
          FirstTrack = cast(StartTrack(Loop, :), 'int8');
          FirstSector = cast(StartSector(Loop, :), 'int8');
       endif
    end
end

% The first sector of the file is now known, so by reading the relevent part of 
% the sector subsequent sectors can be read until the end of the file is reached.

FileSectors = [];
CurrentTrack = FirstTrack;
CurrentSector = FirstSector;
NumberOfSectors = 0;
do
   NumberOfSectors = NumberOfSectors+1;
   Sector = DiskImage(CurrentTrack+1, CurrentSector, :);
   NextTrack = Sector(1);
   NextSector = Sector(2);

   FileSectors = vertcat(FileSectors, Sector);
   CurrentTrack = NextTrack;
   CurrentSector = NextSector;
until ((NextTrack == 0) && (NextSector == 0))
   
fprintf("Number of sectors copied = %i\n", NumberOfSectors);
% The array FileSectors now contains the raw sectors of the data file, which can
% be processed to recover the data, and create both s-recors and Intelhex files.
%
% Binary file sector format is -
%   Byte 0 Next track (or 0 for last sector)
%   Byte 1 Next Sector (or 0 for last sector)
%   Byte 2 Most significant byte of number of sectors in the file
%   Byte 3 Least significant byte of number of sectors in the file
%   Byte 4  ($02)
%   Byte 5 Most significant byte of the load address
%   Byte 6 Least significant byte of the load address
%   Byte 7 Number of data bytes in the record
%   Byte 8-n Binary data

% The best way to proceed from here is to read each byte in turn.
% Start with State = 0
% When $02 is found, go to state 1, read start address and number of bytes
% When address and length is read, go to State = 2, read the number of data bytes.
% When done, go back to State =0, ready to go again.

DataStream = [];
State = 0;
AddressCount = 1;
Address = 0;
Image.AddressList = [];
Image.LengthList = [];
Image.DataList = [];
for Loop1 = 1:NumberOfSectors
   for Loop2 = 5:256
      Byte = FileSectors(Loop1, 1, Loop2);
      switch (State)
      case {0}
         % Looking for the start of record byte, $02
         if (Byte == 2)
            State = 1;
         endif
      case {1}
         % Reading the start address
         if (AddressCount != 2)
            AddressCount++;
            Address = Byte;
         else   
            Address = (Address*256) + Byte;
            AddressCount = 1;
            State = 2;
         endif
      case {2}
         % Now find the number of bytes to copy
         ByteCount = Byte;
         Length = Byte;
         State = 3;
         DataStream = [];
      case {3}
         % and read the data
         DataStream = horzcat(DataStream, Byte);
         ByteCount--;
         if (ByteCount == 0)
            % when completed, reset the status to repeat as needed
            Image.AddressList = vertcat(Image.AddressList, Address);
            Image.LengthList = vertcat(Image.LengthList, Length);
            Image.DataList = strvcat(Image.DataList, DataStream);
            State = 0;
            Address = 0;
         endif
      endswitch
    endfor
endfor


% Now to write the extracted data into an s-record file.
Status = WriteSrecord(OutputFilePath, OutputFileName, Image);
Status = WriteIntelhex(OutputFilePath, OutputFileName, Image);