#include<stdio.h>
#include<stdlib.h>
#include<string.h>
#include<list>
#define MALLOC(TYPE,NUM) ((TYPE *) malloc(NUM * sizeof(TYPE)))
void Perror(const char *str){
    puts(str);
    exit(1);
}
inline FILE *fopen2(const char *filename, const char *mode){
    FILE *file = fopen(filename,mode);
    if (file == NULL) Perror("Fail to open file");
    return file;
}
#include "windows.h"
void Deep_CreateDirectory(const char *path){
    int len = strlen(path);
    char *buffer = MALLOC(char,len + 1);
    strcpy(buffer,path);
    for(int i = 0; i < len; ++i){
        if (buffer[i] == '\\'){
            buffer[i] ='\0';
            CreateDirectory(buffer, (_SECURITY_ATTRIBUTES *) NULL);
            buffer[i] ='\\';
        }
    }
    free(buffer);
}


class FileImf{
public:
    char *filename;
    int pos,size,key;
    FileImf(char *_filename,int _pos, int _size, int _key){
        filename = _filename;
        pos = _pos;
        size = _size;
        key = _key;
    }
    ~FileImf(){
        free(filename);
    }
};


class RGSSAD{
    FILE *file;
    bool Disable_nextKey;
    int magic_key;
    std::list<FileImf*> dataImfs;
//---------------------------------------------
// Base
//---------------------------------------------
    inline char read_char(){
        char byte;
        fread(&byte, 1, 1, file);
        return byte;
    }
    inline int read_int(int read_bytes = 4){
        unsigned char fourBytes[4];
        fread(fourBytes, read_bytes, 1, file);
        return bytes_to_int_Little(fourBytes);
    }
    inline void read_str(char *str, int len){
        fread(str, len, 1, file);
        str[len] = '\0';
    }
    inline int bytes_to_int_Little(unsigned char fourBytes[4]){
        return (fourBytes[0] << 0) | (fourBytes[1] << 8) | (fourBytes[2] << 16) | (fourBytes[3] << 24);
    }
    inline int bytes_to_int_Big(unsigned char fourBytes[4]){
        return (fourBytes[0] << 24) | (fourBytes[1] << 16) | (fourBytes[2] << 8) | (fourBytes[3] << 0);
    }
//---------------------------------------------
// Magic rules
//---------------------------------------------
    inline void next_key(){
        if (Disable_nextKey) return;
        magic_key = magic_key * 7 + 3;
    }
    inline char magic_read_char(){
        char byte = read_char() ^ magic_key;
        if (!feof(file)) next_key();
        return byte;
    }
    inline int magic_read_int(){
        int integer = read_int() ^ magic_key;
        if (!feof(file)) next_key();
        return integer;
    }
    inline void magic_read_str(char *str, int len, int magic_span = 1){
        read_str(str, len);
        if (magic_span == 1){       //apply xor to each byte.
            for(int i = 0; i < len; ++i){
                str[i] ^= magic_key;
                next_key();
            }
        }else if (magic_span == 4){ //apply xor to each four bytes(little endian).
            int count = 0;
            for(int i = 0; i < len; ++i){
                str[i] = (unsigned char) str[i] ^ (magic_key >> (count << 3));
                if (++count == magic_span){
                    count = 0;
                    next_key();
                }
            }
            if (count != 0) next_key();
        }
    }
//---------------------------------------------
// RGSSAD data structure
//---------------------------------------------
    int read_version(){
        char buffer[7];
        read_str(buffer,6);
        if (strcmp("RGSSAD",buffer) != 0) Perror("file format is not RGSSAD");
        char tmp1 = read_char();
        char tmp2 = read_char();
        return (int) tmp1 * 10 + (int) tmp2;
    }

public:
    inline RGSSAD(const char *filename){
        file = fopen2(filename,"rb");
        Disable_nextKey = false;
    }
    ~RGSSAD(){
        fclose(file);
    }
    bool decrypt(const char *path){
        int version = read_version();
        printf("version: %02d\n",version);

        switch(version){
        case 1:{
            magic_key = 0xDEADCAFE;
            while(!feof(file)){
                int nameSize = magic_read_int();
                if (feof(file)) break;
                char *filename = MALLOC(char,nameSize + 1);
                magic_read_str(filename,nameSize);
                int dataSize = magic_read_int();
                int pos = ftell(file);
                fseek(file,dataSize,SEEK_CUR);
                if (!feof(file)) dataImfs.push_back(new FileImf(filename,pos,dataSize,magic_key));
            }
            break;}
        case 3:{
            magic_key = read_int() * 9 + 3;
            Disable_nextKey = true;
            while(!feof(file)){
                int pos = magic_read_int();
                if (feof(file) || pos == 0) break;
                int dataSize = magic_read_int();
                int dataKey  = magic_read_int();
                int nameSize = magic_read_int();
                char *filename = MALLOC(char,nameSize + 1);
                magic_read_str(filename,nameSize,4);
                if (!feof(file)) dataImfs.push_back(new FileImf(filename,pos,dataSize,dataKey));
            }
            Disable_nextKey = false;
            break;}
        default:
            puts("cant decrypt this version.");
            return false;
        }
        //==========================================
        int path_len = strlen(path);
        FILE *f = fopen("log.txt","w");
        while(!dataImfs.empty()){
            FileImf *imf = dataImfs.front();
            dataImfs.pop_front();
            magic_key = imf->key;

            char *filename = MALLOC(char,strlen(imf->filename) + path_len + 2); //+2 for '\0' and '\\'
            char *filedata = MALLOC(char,imf->size + 1);
            sprintf(filename,"%s\\%s",path,imf->filename);
            fseek(file,imf->pos,SEEK_SET);
            magic_read_str(filedata,imf->size,4);

            Deep_CreateDirectory(filename);
            FILE *output = fopen(filename,"wb");
            fwrite((unsigned char*) filedata, sizeof(unsigned char), imf->size, output);
            fprintf(f,"%-60s-%10.3f kb\n",filename,(float)imf->size/1024.0f);

            free(imf);
            free(filename);
            free(filedata);
            fclose(output);
        }
        return true;
    }
};


int main(){
    //RGSSAD file("Game34.rgssAD");
    //if (file.decrypt("c_output\\XP")) puts("Done.");

    RGSSAD file("Game.rgssad");
    if (file.decrypt("c_output\\VA")) puts("Done.");
    return 0;
}
