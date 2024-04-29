close all
clear
clc
filepath = "~/Documents/Old_Computers/6809/Flex/DSK/Flex91";
filename = "FLEX.s09";
OutputFilePath = "~/Documents/Old_Computers/6809/Flex/DSK/Flex91";
OutputFileName = "SortedFlexTest.s09";

[fpath,name,ext] = fileparts(filename);
fullname = [filepath, "/", filename];
fileID = fopen(fullname, "rt+");
Srecord = fread(fileID);
fclose(fileID);

% The whole s-record is read as a single column vector. This can then be 
% parsed is sequence, just like a serial feed.
% The file is read as an array of type double, so contains the ASCII values of the 
% characters. They need to be cast to chars to be readable.
cast (Srecord, "char");

% States used in the state-machine -
% 0 waiting for a new s-record
% 1 s character is received, waiting for the s-type
% 2 S1 received, waiting for record length
% 3 record length received, reading address 
% 4 reading data
% 5 data read, reset ready for the next record

State = 0;
Digit = 0;
RecordLengthChar = [];
AddressChar = [];
AddressList = [];
DataList = [];
DataChar = [];
DataCount = 0;
printf("Reading source file \n");
for Pointer = 1:rows (Srecord)
   % Use a state-machine to process the data into two arrays, one for address and another
   % for data. As each data-point is read, if the address already exists then the existing
   % data value is over-written. This replicates the patches that are in the .cor file.
   CurrentChar = Srecord(Pointer);
   switch (State)
      case {0}
         if (CurrentChar == "S")
            State = 1;    
         endif  
      case {1}
         if (CurrentChar == "1")
            State = 2; 
         else
            State = 0; 
         endif     
      case {2}
         RecordLengthChar = strcat(RecordLengthChar, CurrentChar);
         Digit++;
         if (Digit == 2)
            Digit = 0;
            State = 3;
            RecordLength = hex2dec (RecordLengthChar)-3;
         endif
      case {3}
         AddressChar = strcat(AddressChar, CurrentChar);
         Digit++;
         if (Digit == 4)
            Digit = 0;
            State = 4;
            Address = hex2dec (AddressChar)-1;
         endif
   case {4}
         DataChar = strcat(DataChar, CurrentChar);
         Digit++;
         if (Digit == 2)
            Digit = 0;
            Data = hex2dec (DataChar);
            DataChar = [];
            Address++;
            % Add the data and address to the stored record
            Flag = 0;
            for Loop = 1:rows(AddressList)
               if (AddressList(Loop) == Address)
                  DataList(Loop) = Data;
                  Flag = 1;
               endif
            endfor
            if (Flag == 0)  
               AddressList = vertcat(AddressList, Address);
               DataList = vertcat(DataList, Data);
               if (isnan(Data) == 1)
                  printf("Address = %i\n", Address);
               endif
            endif
            DataCount++;
            if (DataCount == RecordLength)
               State = 5;
            endif
         endif
      case {5}
         State = 0;
         Digit = 0;
         RecordLengthChar = [];
         AddressChar = [];
         DataCount = 0;
   endswitch
endfor
printf("File read, starting sort \n");

% At this point the data is held in AddressList and DataList. To reduce the number 
% of warnings from srecord the addresses should be sorted into ascending order.
% A simple bubble sort is used for this.
for Loop1 = 1:rows(AddressList)-1
   for Loop2 = 1:(rows(AddressList)-Loop1)
      if (AddressList(Loop2) >= AddressList(Loop2+1))
         Address = AddressList(Loop2+1);
         AddressList(Loop2+1) = AddressList(Loop2);
         AddressList(Loop2) = Address;
         Data = DataList(Loop2+1);
         DataList(Loop2+1) = DataList(Loop2);
         DataList(Loop2) = Data;
      endif
   endfor
endfor
printf("Sort complete, write file to disk \n");

% and the new s-record file can be written back to disk.
BytesPerLine = 16;

OutFile = strcat(OutputFilePath, "/", OutputFileName);
% Check if the file exists, and if so delete it.
FileCheck = exist(OutFile, "file");
if FileCheck == 2
  delete (OutFile);
endif

fileID = fopen(OutFile, "at");

BytesPerLine = 16;
ByteCount = 0;
RunningTotal = 0;
Line = [];
for Index = 1:rows(AddressList)
   if (ByteCount == 0)
      Address = AddressList(Index);
      RunningTotal = mod(Address, 256) + fix(Address/256);
   endif
   RunningTotal = RunningTotal + DataList(Index);
   ByteCount++;
   Line = strcat(Line, dec2hex(cast(DataList(Index), 'int16'), 2));
   
   if (Index != rows(AddressList))
      if ((AddressList(Index+1)-AddressList(Index) == 1))
         Flag = 1;
      endif
   else
      Flag = 0;
   endif
   
   if ((ByteCount == BytesPerLine) || (Flag != 1))
      RunningTotal = RunningTotal + ByteCount + 3;
      Checksum = (255 - mod(RunningTotal, 256));
      fprintf(fileID, "S1%s%s%s%s\n", dec2hex(ByteCount+3, 2), dec2hex(Address, 4), Line, dec2hex(Checksum, 2));
      ByteCount = 0;
      Line = [];
      if (Index != rows(AddressList))
         Address = AddressList(Index+1);
      endif
   endif
endfor

fprintf(fileID, "S9030000FC\n");   
fclose(fileID);
printf("Filter complete \n");
