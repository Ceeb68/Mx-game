"""Archive identical-input ground replays without hiding failed scenarios.
Usage: python tools/compare_ground.py BEFORE.json AFTER.json OUTPUT_DIRECTORY
"""
import csv,gzip,json,sys
from pathlib import Path

def passes(row):
    ok=(not row['crashed'] and row['peak_roll_deg']<40
        and abs(row['final_lean_deg'])<25 and row['final_speed_m_s']>.5)
    if row['scenario']=='berm_hold':ok &= row['berm_radius_error_m']<6
    if row['scenario']=='front_unload':ok &= row['contact_ticks'][2]>0
    if row['scenario']=='rear_unload':ok &= row['contact_ticks'][1]>0
    return bool(ok)

def main():
    before,after,out=map(Path,sys.argv[1:])
    out.mkdir(parents=True,exist_ok=True)
    runs={name:json.loads(path.read_text()) for name,path in [('before',before),('after',after)]}
    assert [r['scenario'] for r in runs['before']['results']]==[r['scenario'] for r in runs['after']['results']]
    comparison=[]
    for old,new in zip(runs['before']['results'],runs['after']['results']):
        row={'scenario':new['scenario'],'before_pass':passes(old),'after_pass':passes(new)}
        for key in ['peak_roll_deg','final_lean_deg','peak_roll_rate_rad_s','peak_load_n','final_speed_m_s','berm_radius_error_m']:
            row['before_'+key]=old[key];row['after_'+key]=new[key]
        comparison.append(row)
    (out/'comparison.json').write_text(json.dumps(comparison,indent=2)+'\n')
    with (out/'comparison.csv').open('w') as stream:
        writer=csv.DictWriter(stream,fieldnames=list(comparison[0]),lineterminator='\n');writer.writeheader();writer.writerows(comparison)
    for name,run in runs.items():
        (out/(name+'-results.json')).write_text(json.dumps(run['results'],indent=2)+'\n')
        # Full 240 Hz traces, including flips, remain available; no downsampling.
        with gzip.open(out/(name+'-trace.json.gz'),'wt') as stream:json.dump(run,stream,separators=(',',':'))
        windows={}
        for result in run['results']:
            upset=result['first_upset']
            if upset:
                t=upset['time_s']
                windows[result['scenario']]=[r for r in run['trace'] if r['scenario']==result['scenario'] and t-.05<=r['time_s']<=t+.05]
        (out/(name+'-upset-windows.json')).write_text(json.dumps(windows,indent=2)+'\n')
    for r in comparison:print(r['scenario'],r['before_pass'],r['after_pass'],round(r['before_peak_roll_deg'],2),round(r['after_peak_roll_deg'],2))

if __name__=='__main__':main()
