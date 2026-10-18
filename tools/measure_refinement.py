"""Compare recorded riding telemetry, without treating powered energy as conserved.
Usage: python tools/measure_refinement.py before.json after.json out.json
Input may be gzip; whole-run and identical first-second windows are both retained.
"""
import collections,gzip,json,math,statistics,sys
from pathlib import Path

def read(path):
    return json.loads((gzip.open(path,'rt') if str(path).endswith('.gz') else open(path)).read())
def rms(values):return math.sqrt(statistics.fmean(v*v for v in values)) if values else None
def span(values):return max(values)-min(values) if values else None
def runs(values,dt):
    lengths=[];length=0
    for value in values+[False]:
        if value:length+=1
        elif length:lengths.append(length*dt);length=0
    return {'count':len(lengths),'total_s':sum(lengths),'longest_s':max(lengths,default=0)}
def measure(rows):
    if len(rows)<3:return {}
    dt=rows[1]['time_s']-rows[0]['time_s']
    out={'samples':len(rows),'sample_dt_s':dt,'roll_peak_deg':max(abs(r['lean_deg']) for r in rows),
         'crashed_at_any_sample':any(r['crashed'] for r in rows),
         'pitch_peak_deg':max(abs(math.degrees(math.asin(max(-1,min(1,-r['basis_columns'][2][1]))))) for r in rows)}
    # Sampled finite differences, not engine force/accelerometer measurements.
    az=[(rows[i+1]['position'][1]-2*rows[i]['position'][1]+rows[i-1]['position'][1])/dt**2 for i in range(1,len(rows)-1)]
    out['vertical_acceleration_fd_rms_m_s2']=rms(az)
    out['vertical_acceleration_fd_peak_m_s2']=max(map(abs,az),default=0)
    for index,side in enumerate(['front','rear']):
        data={key:[r[f'{side}_{key}'] for r in rows] for key in ['slip','slip_angle_deg','grip_use','fx_n','fy_n','load_n','compression_m','suspension_velocity_m_s']}
        for key,values in data.items():
            out[side+'_'+key+'_rms']=rms(values)
            out[side+'_'+key+'_peak_abs']=max(map(abs,values))
        out[side+'_load_std_n']=statistics.pstdev(data['load_n'])
        out[side+'_compression_peak_to_peak_m']=span(data['compression_m'])
        out[side+'_contact_interruptions']=runs([not (int(r['contact_mask']) & (1<<index)) for r in rows],dt)
        radius=.355 if index==0 else .335
        out[side+'_rolling_mismatch_rms_m_s']=rms([r[side+'_omega_rad_s']*radius-r[side+'_longitudinal_m_s'] for r in rows if int(r['contact_mask']) & (1<<index)])
    return out

def main():
    before,after,target=sys.argv[1:]
    all_runs={}
    for label,path in [('before',before),('after',after)]:
        data=read(path);groups=collections.defaultdict(list)
        for row in data.get('trace',[]):groups[row['scenario']].append(row)
        all_runs[label]={name:{'whole_run':measure(rows),'first_second':measure([r for r in rows if r['time_s']<1])} for name,rows in groups.items()}
        all_runs[label+'_results']=data['results']
    all_runs['definitions']={'vertical_acceleration':'central second difference of recorded chassis position; landing traces sampled at 30 Hz, ground/contact at 240 Hz; this includes gravity response, collisions and engine/control work', 'rms':'zero-referenced RMS, not oscillatory amplitude; compression peak-to-peak reported separately', 'contact_interruptions':'includes initial airborne interval; zero-load and missing-road contacts both count', 'windows':'first_second is common fixed t<1 s; whole_run includes falls and diverging paths; no post-crash censoring', 'energy':'powered whole-bike kinetic changes are not a closed energy budget; see independent unpowered tire and fixed-mount suspension probes'}
    Path(target).write_text(json.dumps(all_runs,indent=2)+'\n')
if __name__=='__main__':main()
